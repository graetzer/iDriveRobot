//
//  SGSource.h
//  iDriveRobot
//
//  Created by Simon Grätzer on 29.09.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CoreVideo.h>

@protocol SGVideoSourceDelegate <NSObject>

// You should copy the data
- (void)didReceiveData:(NSData *)data;

@end


/**
 * Not used anymore, the SGVideoDriver class replaces this.
 * Captures frames from the iOS camera and encodes them to a x264 stream into a mp4 container.
 * Not that useful beause I only managed to get to about 5fps because ffmpeg is too slow.
 * One could possibly speed up the process by copying the raw data and processing it outside the camera callback queue.
 * But that's a task that is left up to the reader
 */
@interface SGVideoSource : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>

/*!
 @brief The capture session takes the input from the camera and capture it
 */
@property (nonatomic, readonly) AVCaptureSession *captureSession;

+ (SGVideoSource *)shared;
- (void)addDelegate:(id<SGVideoSourceDelegate>)delegate;
- (void)removeDelegate:(id)delegate;

- (void)start;
- (void)stop;

@end
