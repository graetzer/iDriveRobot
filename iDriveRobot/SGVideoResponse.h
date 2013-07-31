//
//  SGVideoResponse.h
//  iDriveRobot
//
//  Created by Simon Grätzer on 30.09.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CoreVideo.h>

#import "HTTPResponse.h"

@class HTTPConnection;
@interface SGVideoResponse : NSObject <HTTPResponse>
@property (assign, nonatomic) UInt64 offset;

- (id)initWithConnection:(HTTPConnection *)connection;
@end
