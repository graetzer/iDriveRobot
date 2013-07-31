//
//  SGViewController.h
//  iDriveRobot
//
//  Created by Simon Grätzer on 28.09.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <ifaddrs.h>
#import <arpa/inet.h>

@interface SGViewController : UIViewController
@property (weak, nonatomic) IBOutlet UILabel *ipLabel;

- (IBAction)valChanged:(id)sender;

@end
