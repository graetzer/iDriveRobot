//
//  SGAppDelegate.m
//  iDriveRobot
//
//  Created by Simon Grätzer on 28.09.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import "SGAppDelegate.h"
#import "SGViewController.h"

#import "HTTPServer.h"
#import "SGHTTPConnection.h"
#import "DDLog.h"
#import "DDTTYLogger.h"
#import "SGVideoDriver.h"

@implementation SGAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.viewController = [[SGViewController alloc] initWithNibName:@"SGViewController" bundle:nil];
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
	
	// Initalize our http server
	self.httpServer = [[HTTPServer alloc] init];
	
	// Tell server to use our custom MyHTTPConnection class.
	[self.httpServer setConnectionClass:[SGHTTPConnection class]];
	
	// Tell the server to broadcast its presence via Bonjour.
	// This allows browsers such as Safari to automatically discover our service.
	[self.httpServer setType:@"_http._tcp."];
	
	// Normally there's no need to run our server on any specific port.
	// Technologies like Bonjour allow clients to dynamically discover the server's port at runtime.
	// However, for easy testing you may want force a certain port so you can just hit the refresh button.
    [self.httpServer setPort:8080];
	
	// Serve files from our embedded Web folder
	NSString *webPath = [[NSBundle mainBundle] pathForResource:@"Web" ofType:@"bundle"];
	DDLogVerbose(@"Setting document root: %@", webPath);
	
	[self.httpServer setDocumentRoot:webPath];
	
	// Start the server (and check for problems)
	
	NSError *error;
	BOOL success = [self.httpServer start:&error];
	
	if(!success) {
		DDLogError(@"Error starting HTTP Server: %@", error);
	}
    
    [[SGVideoDriver shared] start];
    
//    [[SGVideoSource shared] start];
//    
//    double delayInSeconds = 20.0;
//    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
//    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
//        [[SGVideoSource shared] stop];
//    });
    
    return YES;
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    [[SGVideoDriver shared] stop];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    [[SGVideoDriver shared] start];
}

@end
