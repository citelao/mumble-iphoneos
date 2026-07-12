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
    NSLog(@"Starting call - joined server as user: %@", user);
    CXHandle* handle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:@"Test call"];
    _callUuid = [NSUUID UUID];
    CXStartCallAction* action = [[CXStartCallAction alloc] initWithCallUUID:_callUuid handle:handle];
    CXTransaction* transaction = [[CXTransaction alloc] initWithAction:action];
    
    [_cxCallController requestTransaction:transaction completion:^(NSError * _Nullable error) {
        // TODO: handle error
        NSLog(@"Requested transaction to start call with error: %@", error);
    }];
}

- (void) serverModelDisconnected:(MKServerModel *)model {
    // TODO: end the call
    NSLog(@"Disconnected from server, ending call");
    
    CXEndCallAction* action = [[CXEndCallAction alloc] initWithCallUUID:_callUuid];
    CXTransaction* transaction = [[CXTransaction alloc] initWithAction:action];
    
    [_cxCallController requestTransaction:transaction completion:^(NSError * _Nullable error) {
        // TODO: handle error
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
}

@end
