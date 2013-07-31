//
//  SGRobot.h
//  iDriveRobot
//
//  Created by Simon Grätzer on 06.10.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

#import "CharReceiver.h"

@class AudioSignalAnalyzer, FSKSerialGenerator;

@interface SGRobot : NSObject <AVAudioSessionDelegate, CharReceiver>
@property (strong, nonatomic) AudioSignalAnalyzer* analyzer;
@property (strong, nonatomic) FSKSerialGenerator* generator;

+ (id)shared;

- (void)setLED:(BOOL)on;
@end
