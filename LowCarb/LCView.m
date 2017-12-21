//
//  LCView.m
//  LowCarb
//
//  Created by Gabriel de Dietrich on 12/5/17.
//  Copyright © 2017 Gabriel de Dietrich. All rights reserved.
//

#import "LCView.h"

@implementation LCView

- (void)awakeFromNib {
    [self createBackingStore];
    ((NSNumberFormatter *)self.frameHeightText.cell.formatter).positiveSuffix = @" px";
    self.frameHeightText.font = [NSFont monospacedDigitSystemFontOfSize:[NSFont systemFontSize]
                                                                 weight:NSFontWeightRegular];
}

- (void)createBackingStore {
    _backingStore.width = self.frame.size.width;
    _backingStore.height = self.frame.size.height;
    _backingStore.bitsPerComponent = 8;
    _backingStore.componentsPerPixel = 4;
    _backingStore.bytesPerPixel = _backingStore.bitsPerComponent * _backingStore.componentsPerPixel / 8;
    _backingStore.data = calloc(_backingStore.width * _backingStore.height, _backingStore.bytesPerPixel);

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserverForName:NSWindowDidBecomeMainNotification
                    object:self.window
                     queue:nil
                usingBlock:^(NSNotification* n) {
                    [self redraw:self];
                }];
    [nc addObserverForName:NSWindowDidResignMainNotification
                    object:self.window
                     queue:nil
                usingBlock:^(NSNotification* n) {
                    [self redraw:self];
                }];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    if (!self.control)
        return;

    [self drawControl];

    if (!self.backingStore.data)
        [self createBackingStore];

    CGDirectDisplayID mainDisplay = CGMainDisplayID();
    CGColorSpaceRef bsCS = CGDisplayCopyColorSpace(mainDisplay);
    CGContextRef bsContext = CGBitmapContextCreate(self.backingStore.data,
                                                   self.backingStore.width,
                                                   self.backingStore.height,
                                                   self.backingStore.bitsPerComponent,
                                                   self.backingStore.width * self.backingStore.bytesPerPixel,
                                                   bsCS,
                                                   kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
    CGColorSpaceRelease(bsCS);

    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext =
        [NSGraphicsContext graphicsContextWithCGContext:bsContext
                                                flipped:YES];
    [NSColor.clearColor setFill];
    NSRectFill(CGRectMake(0, 0, self.backingStore.width, self.backingStore.height));
    const CGFloat scalingFactor = self.window.backingScaleFactor;
    CGContextScaleCTM(bsContext, scalingFactor, scalingFactor);
    [self drawControl];
    [NSGraphicsContext restoreGraphicsState];

    CGImageRef bsImage = CGBitmapContextCreateImage(bsContext);
    CGContextRelease(bsContext);

    CGContextRef ctx = NSGraphicsContext.currentContext.CGContext;
    CGContextSaveGState(ctx);
    CGContextScaleCTM(ctx, 1.0 / scalingFactor, 1.0 / scalingFactor);
    CGContextDrawImage(ctx, CGRectMake(120 * scalingFactor, 0, self.backingStore.width, self.backingStore.height), bsImage);
    CGContextRestoreGState(ctx);
}

- (void)drawControl {
    [self addSubview:self.control];
    self.control.enabled = self.enabledCheckbox.state == NSControlStateValueOn;

    CGRect controlFrame = CGRectMake(20, 20, 100, self.frameHeightSlider.intValue);

    if (self.boudingRectsCheckbox.state == NSControlStateValueOn) {
        [[NSColor.redColor colorWithAlphaComponent:0.5] setFill];
        NSRectFillUsingOperation(controlFrame, NSCompositingOperationSourceOver);

        [[NSColor.yellowColor colorWithAlphaComponent:0.5] setFill];
        NSRectFillUsingOperation([self.control alignmentRectForFrame:controlFrame], NSCompositingOperationSourceOver);

        CGRect drawingBounds = [self.control.cell drawingRectForBounds:CGRectMake(0, 0, 100, 26)];
        [[NSColor.greenColor colorWithAlphaComponent:0.5] setFill];
        drawingBounds.origin.x += controlFrame.origin.x;
        drawingBounds.origin.y += controlFrame.origin.y;
        NSRectFillUsingOperation(drawingBounds, NSCompositingOperationSourceOver);
    }

//    self.control.cell.highlighted = self.pressedCheckbox.state == NSControlStateValueOn;

    if ([self.control isKindOfClass:NSButton.class]) {
        NSButton *button = (NSButton *)self.control;
        [button highlight:self.pressedCheckbox.state == NSControlStateValueOn];
        button.state = self.onStateCheckbox.state;

        if (self.controlType == CheckBox || self.controlType == RadioButton)
            [self.control.cell drawInteriorWithFrame:controlFrame inView:self.control];
        else
            [button.cell drawBezelWithFrame:controlFrame inView:self.control];
    } else {
        if (self.controlType == ComboBox) {
            CGPoint dropDownPoint = CGPointMake(controlFrame.origin.x + self.control.frame.size.width - 10,
                                                controlFrame.origin.y + self.control.frame.size.height / 2.0);
            if (self.pressedCheckbox.state == NSControlStateValueOn)
                [self.control.cell startTrackingAt:dropDownPoint inView:self];
            else if (self.pressedCheckbox.state == NSControlStateValueOff)
                [self.control.cell stopTracking:dropDownPoint at:dropDownPoint inView:self mouseIsUp:YES];
        }
        [self.control.cell drawWithFrame:controlFrame inView:self.control];
    }

    if (self.focusRingCheckbox.state == NSControlStateValueOn) {
        NSGraphicsContext *nsCtx = NSGraphicsContext.currentContext;
        CGContextRef ctx = nsCtx.CGContext;
        [NSGraphicsContext saveGraphicsState];
        CGContextSaveGState(ctx);
        NSSetFocusRingStyle(NSFocusRingOnly);
        CGContextBeginTransparencyLayerWithRect(ctx, controlFrame, nil);
        self.control.cell.showsFirstResponder = YES;
        [self.control.cell drawFocusRingMaskWithFrame:controlFrame inView:self.control];
        CGContextEndTransparencyLayer(ctx);
        CGContextRestoreGState(ctx);
        [NSGraphicsContext restoreGraphicsState];
    } else {
        [self.control drawFocusRingMask];
    }

    [self.control removeFromSuperviewWithoutNeedingDisplay];
}

- (IBAction)redraw:(id)sender {
    [self.frameHeightText takeIntValueFrom:self.frameHeightSlider];
    self.needsDisplay = YES;
}

- (IBAction)controlTypeSelected:(NSPopUpButton *)sender {
    const NSControlSize oldControlSize = self.control.controlSize;
    self.controlType = sender ? [sender indexOfItem:sender.selectedItem] : Button;
    if (self.controlType == ComboBox) {
        self.control = [[NSComboBox alloc] init];
    } else if (self.controlType == TextField) {
        self.control = [[NSTextField alloc] init];
    } else {
        NSButton *button = nil;
        if (self.controlType == Button || self.controlType >= CheckBox) {
            button = [[NSButton alloc] init];
            if (self.controlType == Button) {
                button.buttonType = NSPushOnPushOffButton;
                button.bezelStyle = NSRoundedBezelStyle;
            } else if (self.controlType == RadioButton) {
                button.buttonType = NSRadioButton;
            } else if (self.controlType == CheckBox) {
                button.buttonType = NSSwitchButton;
            }
        } else {
            button = [[NSPopUpButton alloc] init];
            if (self.controlType == PullDownButton)
                ((NSPopUpButton *)button).pullsDown = YES;
        }
        button.title = @"";
        self.control = button;
    }
    self.control.controlSize = oldControlSize;

    [self redraw:sender];
}

- (IBAction)controlSizeSelected:(NSButton *)sender {
    if (!self.control)
        [self controlTypeSelected:nil];

    switch (sender.tag) {
        case 0:
            self.control.controlSize = NSControlSizeRegular;
            break;
        case 1:
            self.control.controlSize = NSControlSizeSmall;
            break;
        case 2:
            self.control.controlSize = NSControlSizeMini;
            break;
        default:
            break;
    }

    [self redraw:sender];
}

@end