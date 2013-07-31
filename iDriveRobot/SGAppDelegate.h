//
//  SGAppDelegate.h
//  iDriveRobot
//
//  Created by Simon Grätzer on 28.09.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SGViewController, HTTPServer;

@interface SGAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) SGViewController *viewController;

@property (strong, nonatomic) HTTPServer *httpServer;
@end
