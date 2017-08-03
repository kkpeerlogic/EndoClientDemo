//
//  EndoViewController.m
//  EndoClientDemo
//
//  Created by kkpeerlogic on 08/03/2017.
//  Copyright (c) 2017 kkpeerlogic. All rights reserved.
//

#import "EndoViewController.h"

@interface EndoViewController ()

@end

@implementation EndoViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    EndoAddCommand(@"testEndo", @"Testing Endo", ^(NSArray<NSString*>*parameters)
                   {
                       NSLog(@"Calling EndoClient");
                   });
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
