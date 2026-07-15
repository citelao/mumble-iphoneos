// Copyright 2009-2026 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUCallController.h"
#import "MUConnectionController.h"
#import <CallKit/CallKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MumbleKit/MKAudio.h>

@interface MUCallController () <MKServerModelDelegate, CXProviderDelegate> {
    MKConnection     *_connection;
    MKServerModel    *_model;
    CXProvider       *_cxProvider;
    CXCallController *_cxCallController;

    NSUUID           *_callUuid;
}
@end

@implementation MUCallController

- (id) init {
    if ((self = [super init])) {
        // MKServerModelDelegate has a serverModelDisconnected: callback, but MKServerModel
        // is the messageHandler of MKConnection, not its delegate, so connection:closedWithError:
        // (the only code path that fires serverModelDisconnected:) is never called by MKConnection.
        // MUConnectionClosedNotification is posted unconditionally at the end of every teardown
        // and is the reliable lifecycle event to use here.
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(connectionClosed:)
                                                     name:MUConnectionClosedNotification
                                                   object:nil];

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_14_0
        CXProviderConfiguration* cxConfig = [[CXProviderConfiguration alloc] init];
#else
        // initWithLocalizedName: is deprecated in iOS 14; init reads the name from the app bundle.
        CXProviderConfiguration* cxConfig = [[CXProviderConfiguration alloc] initWithLocalizedName:@"Mumble"];
#endif
        cxConfig.iconTemplateImageData = UIImagePNGRepresentation([UIImage imageNamed:@"MumbleCallKitIcon"]);
        cxConfig.supportsVideo = NO;
        cxConfig.maximumCallGroups = 1;
        cxConfig.maximumCallsPerCallGroup = 1;
        cxConfig.supportedHandleTypes = [NSSet setWithObject:[NSNumber numberWithInteger:CXHandleTypeGeneric]];

        cxConfig.includesCallsInRecents = NO; // TODO: we might be able to support re-joining from the recents page, but not yet.

        // CXProvider must be created once per app lifetime. Recreating it on each reconnect
        // causes CallKit to ignore subsequent CXStartCallActions.
        _cxProvider = [[CXProvider alloc] initWithConfiguration:cxConfig];
        [_cxProvider setDelegate:self queue:nil];

        _cxCallController = [[CXCallController alloc] init];
    }
    return self;
}

- (void) connectionEstablished:(MKConnection *)conn serverModel:(MKServerModel *)model {
    _connection = conn;
    _model = model;
    [_model addDelegate:self];
}

- (void) connectionTornDown {
    [_model removeDelegate:self];
    _model = nil;
    _connection = nil;
}

- (void) disconnectCurrentCall {
    // Clear before teardown so a re-entrant connectionClosed: sees nil and skips
    // sending a redundant CXEndCallAction for a call CallKit is already ending.
    _callUuid = nil;
    [[MUConnectionController sharedController] disconnectFromServer];
}

+ (NSString *) callNameForUser:(MKUser *)user andHostname:(NSString *)hostname {
    // Name:
    //    @"{host}" if root
    //    @"{channel} on {host}" otherwise
    NSString *callName;
    bool isRootChannel = [[user channel] parent] == nil;
    if (isRootChannel) {
        callName = hostname;
    } else {
        callName = [NSString stringWithFormat:NSLocalizedString(@"%@ on %@", @"channel on hostname (CallKit call name)"), [[user channel] channelName], hostname];
    }
    return callName;
}

#pragma mark - MKServerModelDelegate

- (void) serverModel:(MKServerModel *)model joinedServerAsUser:(MKUser *)user {
    NSLog(@"Starting call - joined server as user: %@, host: %@, channel: %@", user, [model hostname], [[user channel] channelName]);

    NSString *callName = [self.class callNameForUser:user andHostname:[model hostname]];
    CXHandle* handle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:callName];
    _callUuid = [NSUUID UUID];
    CXStartCallAction* action = [[CXStartCallAction alloc] initWithCallUUID:_callUuid handle:handle];
    CXTransaction* transaction = [[CXTransaction alloc] initWithAction:action];

    [_cxCallController requestTransaction:transaction completion:^(NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"MUCallController: failed to start CallKit call: %@", error);
            // Clear the UUID so connectionClosed: doesn't try to end a call that never started.
            self->_callUuid = nil;
        }
    }];
}

- (void) serverModel:(MKServerModel *)model userMoved:(MKUser *)user toChannel:(MKChannel *)chan fromChannel:(MKChannel *)prevChan byUser:(MKUser *)mover {
    BOOL isConnectedUser = [_model connectedUser] == user;
    if (!isConnectedUser) {
        // We only care about the current user moving.
        return;
    }
    
    if (_callUuid != nil) {
        NSLog(@"MUCallController: no call active, ignoring channel change");
        return;
    }
    CXCallUpdate *callUpdate = [CXCallUpdate new];
    callUpdate.localizedCallerName = [self.class callNameForUser:user andHostname:[model hostname]];
    [_cxProvider reportCallWithUUID:_callUuid updated:callUpdate];
}

- (void) serverModel:(MKServerModel *)model channelRenamed:(MKChannel *)channel {
    BOOL isConnectedUsersChannel = [[_model connectedUser] channel] == channel;
    if (!isConnectedUsersChannel) {
        // We only care about the current user's channel.
        return;
    }
    
    if (_callUuid != nil) {
        NSLog(@"MUCallController: no call active, ignoring channel change");
        return;
    }
    CXCallUpdate *callUpdate = [CXCallUpdate new];
    callUpdate.localizedCallerName = [self.class callNameForUser:[_model connectedUser] andHostname:[model hostname]];
    [_cxProvider reportCallWithUUID:_callUuid updated:callUpdate];
}

- (void) connectionClosed:(NSNotification *)notification {
    if (_callUuid == nil) {
        return;
    }
    NSLog(@"Disconnected from server, ending call");
    CXEndCallAction *action = [[CXEndCallAction alloc] initWithCallUUID:_callUuid];
    _callUuid = nil;
    CXTransaction *transaction = [[CXTransaction alloc] initWithAction:action];
    [_cxCallController requestTransaction:transaction completion:^(NSError *error) {
        NSLog(@"Requested transaction to disconnect call with error: %@", error);
    }];
}

#pragma mark - CXProviderDelegate

- (void)providerDidReset:(nonnull CXProvider *)provider {
    NSLog(@"Call provider reset");
    [self disconnectCurrentCall];
}

- (void)provider:(CXProvider *)provider performStartCallAction:(CXStartCallAction *)action {
    NSLog(@"Perform start call");

    [provider reportOutgoingCallWithUUID:action.callUUID startedConnectingAtDate:[NSDate date]];

    // CallKit requires a configured AVAudioSession when starting a call; it
    // activates the Session & hands it off via provider:didActivateAudioSession:.
    // MKAudio does similar configuration, but it also starts the Session after
    // that configuration, which breaks CallKit assumption. To avoid that, we 
    // configure the Session here, let CallKit start it, and then initialize
    // MKAudio *after* that Session is active. This has the effect of ignoring
    // configuration done by MKAudio, so we aspire to keep the flags close here.
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error = nil;

    [session setCategory:AVAudioSessionCategoryPlayAndRecord
                    mode:AVAudioSessionModeVoiceChat
                 options:AVAudioSessionCategoryOptionAllowBluetoothHFP | AVAudioSessionCategoryOptionDefaultToSpeaker
                   error:&error];

    NSLog(@"AVAudioSession config error: %@", error);

    [action fulfill];
    [provider reportOutgoingCallWithUUID:action.callUUID connectedAtDate:[NSDate date]];

    CXCallUpdate* callUpdate = [CXCallUpdate new];
    callUpdate.supportsDTMF = NO; // No "Keypad"
    callUpdate.supportsHolding = NO;
    callUpdate.supportsGrouping = NO;
    callUpdate.supportsUngrouping = NO;
    [provider reportCallWithUUID:action.callUUID updated:callUpdate];
}

- (void)provider:(CXProvider *)provider didActivateAudioSession:(AVAudioSession *)audioSession {
    NSLog(@"CallKit didActivateAudioSession");
    if (![[MKAudio sharedAudio] isRunning]) {
        NSLog(@"MUCallController: MKAudio not running. Starting it.");
        [[MKAudio sharedAudio] start];
    } else {
        NSLog(@"MUCallController: MKAudio running. RESTARTING it.");
        [[MKAudio sharedAudio] restart];
    }
}

- (void)provider:(CXProvider *)provider didDeactivateAudioSession:(AVAudioSession *)audioSession {
    NSLog(@"CallKit didDeactivateAudioSession");
    [[MKAudio sharedAudio] stop];
}

- (void)provider:(CXProvider *)provider performEndCallAction:(CXEndCallAction *)action {
    NSLog(@"CallKit performEndCallAction");
    // Guard: if _callUuid is nil the call was already torn down from our side
    // (e.g. app-initiated disconnect). Calling disconnectCurrentCall here would
    // tear down a new connection the user may have already started.
    if (_callUuid != nil) {
        [self disconnectCurrentCall];
    }
    [action fulfill];
}

- (void)provider:(CXProvider *)provider performSetMutedCallAction:(CXSetMutedCallAction *)action {
    NSLog(@"CallKit requested mute: %@", [action isMuted] ? @"YES" : @"NO");

    // Uniltarally clear deafened state; sorry!
    [_model setSelfMuted:[action isMuted] andSelfDeafened:NO];
    [action fulfill];
}

@end
