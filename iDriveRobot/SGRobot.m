//
//  SGRobot.m
//  iDriveRobot
//
//  Created by Simon Grätzer on 06.10.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import "SGRobot.h"
#import "CharReceiver.h"
#import "AudioSignalAnalyzer.h"
#import "FSKRecognizer.h"
#import "FSKSerialGenerator.h"

@implementation SGRobot {
    FSKRecognizer *_recognizer;
}

+ (id)shared {
    static id shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (id)init {
    if (self = [super init]) {
        AVAudioSession *session = [AVAudioSession sharedInstance];
        session.delegate = self;
        if(session.inputAvailable){
            [session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
        } else {
            [session setCategory:AVAudioSessionCategoryPlayback error:nil];
        }
        [session setActive:YES error:nil];
        [session setPreferredIOBufferDuration:0.023220 error:nil];
        
        self.generator = [[FSKSerialGenerator alloc] init];
        [self.generator play];
        
        _recognizer = [[FSKRecognizer alloc] init];
        [_recognizer addReceiver:self];
        
        self.analyzer = [[AudioSignalAnalyzer alloc] init];
        [self.analyzer addRecognizer:_recognizer];
        
        if(session.inputAvailable){
            [self.analyzer record];
        }

    }
    return self;
}

- (void)inputIsAvailableChanged:(BOOL)isInputAvailable
{
	NSLog(@"inputIsAvailableChanged %d",isInputAvailable);
	
	AVAudioSession *session = [AVAudioSession sharedInstance];
	
	[self.analyzer stop];
	[self.generator stop];
	
	if(isInputAvailable){
		[session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
		[self.analyzer record];
	}else{
		[session setCategory:AVAudioSessionCategoryPlayback error:nil];
	}
	[self.generator play];
}

- (void)beginInterruption
{
	NSLog(@"beginInterruption");
    [self.analyzer stop];
    [self.generator pause];
}

- (void)endInterruption
{
	NSLog(@"endInterruption");
    [self.analyzer record];
    [self.generator resume];
}

- (void)endInterruptionWithFlags:(NSUInteger)flags
{
	NSLog(@"endInterruptionWithFlags: %x",flags);
}

- (void)setLED:(BOOL)on {
    [self.generator writeByte:(UInt8)'a'];
}

- (void) receivedChar:(char)input {
    NSLog(@"Received: %c", input);
}

@end
