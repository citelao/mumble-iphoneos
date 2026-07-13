// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUCallController.h"
#import "MUConnectionController.h"
#import <CallKit/CallKit.h>
#import <AVFoundation/AVFoundation.h>

@interface MUCallController () <MKServerModelDelegate, CXProviderDelegate> {
    MKConnection     *_connection;
    MKServerModel    *_model;
    CXProvider       *_cxProvider;
    CXCallController *_cxCallController;
    
    NSUUID           *_callUuid;
}
@end

@implementation MUCallController

- (id) initWithConnection:(MKConnection *)conn andServerModel:(MKServerModel *)model {
    if ((self = [super init])) {
        _connection = conn;
        _model = model;
        [_model addDelegate:self];

        // MKServerModelDelegate has a serverModelDisconnected: callback, but MKServerModel
        // is the messageHandler of MKConnection, not its delegate, so connection:closedWithError:
        // (the only code path that fires serverModelDisconnected:) is never called by MKConnection.
        // MUConnectionClosedNotification is posted unconditionally at the end of every teardown
        // and is the reliable lifecycle event to use here.
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(connectionClosed:)
                                                     name:MUConnectionClosedNotification
                                                   object:nil];

        CXProviderConfiguration* cxConfig = [[CXProviderConfiguration alloc] initWithLocalizedName:@"Mumble"];
        cxConfig.supportsVideo = NO;
        cxConfig.maximumCallGroups = 1;
        cxConfig.maximumCallsPerCallGroup = 1;
        cxConfig.supportedHandleTypes = [NSSet setWithObject:[NSNumber numberWithInteger:CXHandleTypeGeneric]];
        
        _cxProvider = [[CXProvider alloc] initWithConfiguration:cxConfig];
        [_cxProvider setDelegate:self queue:nil];
        
        _cxCallController = [[CXCallController alloc] init];
    }
    return self;
}

- (void) disconnectCurrentCall {
    // End the call!
    [[MUConnectionController sharedController] disconnectFromServer];
    _callUuid = nil;
}

#pragma mark - MKServerModelDelegate

- (void) serverModel:(MKServerModel *)model joinedServerAsUser:(MKUser *)user {
    NSLog(@"Starting call - joined server as user: %@, host: %@, channel: %@", user, [model hostname], [user channel]);
    
    // TODO: name call
    CXHandle* handle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:@"Test call"];
    _callUuid = [NSUUID UUID];
    CXStartCallAction* action = [[CXStartCallAction alloc] initWithCallUUID:_callUuid handle:handle];
    CXTransaction* transaction = [[CXTransaction alloc] initWithAction:action];
    
    [_cxCallController requestTransaction:transaction completion:^(NSError * _Nullable error) {
        // TODO: handle error
        NSLog(@"Requested transaction to start call with error: %@", error);
    }];
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
    
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error = nil;

    [session setCategory:AVAudioSessionCategoryPlayAndRecord
                    mode:AVAudioSessionModeVoiceChat
                 options:AVAudioSessionCategoryOptionAllowBluetoothHFP
                   error:&error];

    NSLog(@"AVAudioSession config error: %@", error);
    
    [action fulfill];
    [provider reportOutgoingCallWithUUID:action.callUUID connectedAtDate:[NSDate date]];
}

- (void)provider:(CXProvider *)provider didActivateAudioSession:(AVAudioSession *)audioSession {
    NSLog(@"CallKit didActivateAudioSession");
}

- (void)provider:(CXProvider *)provider didDeactivateAudioSession:(AVAudioSession *)audioSession {
    NSLog(@"CallKit didDeactivateAudioSession");
}

- (void)provider:(CXProvider *)provider performEndCallAction:(CXEndCallAction *)action {
    NSLog(@"CallKit performEndCallAction");
    [self disconnectCurrentCall];
    [action fulfill];
}

- (void)provider:(CXProvider *)provider performSetMutedCallAction:(CXSetMutedCallAction *)action {
    NSLog(@"CallKit requested mute: %@", [action isMuted] ? @"YES" : @"NO");

    // Uniltarally clear deafened state; sorry!
    [_model setSelfMuted:[action isMuted] andSelfDeafened:NO];
    [action fulfill];
}

@end
