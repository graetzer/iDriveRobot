//
//  SGVideoResponse.m
//  iDriveRobot
//
//  Created by Simon Grätzer on 30.09.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import "SGVideoResponse.h"
#import "HTTPConnection.h"
#import "SGVideoDriver.h"


@implementation SGVideoResponse {
    HTTPConnection *_connection;
    NSData *_buffer;
    BOOL _done;
}

- (id)initWithConnection:(HTTPConnection *)connection {
    if (self = [super init]) {
        _connection = connection;
        _buffer = [[SGVideoDriver shared] jpegImage];
    }
    
    return self;
}

- (NSInteger)status {
    return 200;
}

- (NSDictionary *)httpHeaders {
    return @{@"Content-Type" : @"image/jpeg",
    @"Content-Disposition" : @"attachment; filename=\"livefeed.jpeg\""};
}

- (UInt64)contentLength {
    return _buffer.length;
}

- (NSData *)readDataOfLength:(NSUInteger)length {
    UInt64 remainingBytes = _buffer.length - self.offset;
    if (remainingBytes <= length) {
        length = remainingBytes;
        _done = YES;
    }    
    const void* pointer = _buffer.bytes;
    NSData *r = [NSData dataWithBytesNoCopy:(void*)pointer + _offset
                                     length:length freeWhenDone:NO];
    self.offset += length;
    return r;
}

// SGSourceDelegate
- (void)didReceiveData:(NSData *)data {
    [_connection responseHasAvailableData:self];
}

- (BOOL)isDone {
    return _done;
}

@end
