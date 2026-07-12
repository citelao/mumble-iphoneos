// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUCallController.h"
#import <CallKit/CallKit.h>

@interface MUCallController () <MKServerModelDelegate, CXProviderDelegate> {
    MKConnection     *_connection;
    MKServerModel    *_model;
    CXProvider       *_cxProvider;
    CXCallController *_cxCallController;
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

#pragma mark - MKServerModelDelegate

- (void) serverModel:(MKServerModel *)model joinedServerAsUser:(MKUser *)user {
    // TODO: start a call

    // log for now:
    NSLog(@"Joined server as user: %@", user);
    
    CXHandle* handle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:@"Test call"];
    NSUUID *uuid = [NSUUID UUID];
    CXStartCallAction* action = [[CXStartCallAction alloc] initWithCallUUID:uuid handle:handle];
    CXTransaction* transaction = [[CXTransaction alloc] initWithAction:action];
    
    [_cxCallController requestTransaction:transaction completion:^(NSError * _Nullable error) {
        // TODO: handle error
        NSLog(@"Requested transaction to start call with error: %@", error);
    }];
}

- (void) serverModelDisconnected:(MKServerModel *)model {
    // TODO: end the call
    NSLog(@"Disconnected from server, ending call");
}

#pragma mark - CXProviderDelegate

- (void)providerDidReset:(nonnull CXProvider *)provider {
    // TODO: disconnect from session
    NSLog(@"Call provider reset");
}

- (void)provider:(CXProvider *)provider performStartCallAction:(CXStartCallAction *)action {
    NSLog(@"Perform start call");
    
    [provider reportOutgoingCallWithUUID:action.callUUID startedConnectingAtDate:[NSDate date]];
    [action fulfill];
    [provider reportOutgoingCallWithUUID:action.callUUID connectedAtDate:[NSDate date]];
}

- (void)provider:(CXProvider *)provider didActivateAudioSession:(AVAudioSession *)audioSession {
    NSLog(@"CallKit didActivateAudioSession");
}

- (void)provider:(CXProvider *)provider didDeactivateAudioSession:(AVAudioSession *)audioSession {
    NSLog(@"CallKit didDeactivateAudioSession");
}

@end
