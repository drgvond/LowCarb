//
//  ViewController.m
//  LowCarb
//
//  Created by Gabriel de Dietrich on 12/5/17.
//  Copyright © 2017 Gabriel de Dietrich. All rights reserved.
//

#import "ViewController.h"
#import "LCView.h"

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.controlView controlTypeSelected:nil];
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

@end
