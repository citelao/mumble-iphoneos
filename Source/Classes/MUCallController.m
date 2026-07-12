// Copyright 2009-2010 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUCallController.h"

@interface MUCallController () <MKServerModelDelegate> {
    MKConnection    *_connection;
    MKServerModel   *_model;
}
@end

@implementation MUCallController

- (id) initWithConnection:(MKConnection *)conn andServerModel:(MKServerModel *)model {
    if ((self = [super init])) {
        _connection = conn;
        _model = model;
        [_model addDelegate:self];
    }
    return self;
}

#pragma mark - MKServerModelDelegate

- (void) serverModel:(MKServerModel *)model joinedServerAsUser:(MKUser *)user {
    // TODO: start a call

    // log for now:
    NSLog(@"Joined server as user: %@", user);
}

- (void) serverModelDisconnected:(MKServerModel *)model {
    // TODO: end the call
    NSLog(@"Disconnected from server, ending call");
}

@end
