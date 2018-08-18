//
//  LCView.h
//  LowCarb
//
//  Created by Gabriel de Dietrich on 12/5/17.
//  Copyright © 2017 Gabriel de Dietrich. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ViewController;

struct BackingStore {
    int width;
    int height;
    int bitsPerComponent;
    int bytesPerPixel;
    int componentsPerPixel;
    void *data;
};

typedef NS_ENUM(NSInteger, ControlType) {
    Box,
    Button,
    PopUpButton,
    PullDownButton,
    CheckBox,
    RadioButton,
    TextField,
    ComboBox
};

@interface LCView : NSView

@property NSView *control;
@property ControlType controlType;
@property NSControlSize controlSize;
@property struct BackingStore backingStore;

@property (weak) IBOutlet NSButton *boudingRectsCheckbox;
@property (weak) IBOutlet NSButton *focusRingCheckbox;
@property (weak) IBOutlet NSButton *enabledCheckbox;
@property (weak) IBOutlet NSButton *pressedCheckbox;
@property (weak) IBOutlet NSButton *onStateCheckbox;
@property (weak) IBOutlet NSSlider *frameHeightSlider;
@property (weak) IBOutlet NSTextField *frameHeightText;

- (IBAction)controlTypeSelected:(NSPopUpButton *)sender;
- (IBAction)controlSizeSelected:(NSButton *)sender;

@end
