//
//  LCView.m
//  LowCarb
//
//  Created by Gabriel de Dietrich on 12/5/17.
//  Copyright © 2017 Gabriel de Dietrich. All rights reserved.
//

#import "LCView.h"

@interface NSComboBoxCell (ButtonCell)
@property (readonly) NSButtonCell *buttonCell;
@end

@implementation NSComboBoxCell (ButtonCell)
- (NSButtonCell *)buttonCell {
    return (NSButtonCell *)[self valueForKeyPath:@"_buttonCell"];
}
@end

@interface CustomNSBox : NSBox

- (instancetype)init;
- (void)drawRect:(NSRect)dirtyRect;

@end

@implementation CustomNSBox

- (instancetype)init {
    self = [super init];
    if (self) {
        self.title = @"";
        self.titlePosition = NSNoTitle;
    }

    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
}

@end


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

    // Direct draw on the left hand side
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

    // First, draw into the backing store
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext =
        [NSGraphicsContext graphicsContextWithCGContext:bsContext
                                                flipped:NO];
    [NSColor.clearColor setFill];
    NSRectFill(CGRectMake(0, 0, self.backingStore.width, self.backingStore.height));
    const CGFloat scalingFactor = self.window.backingScaleFactor;
    CGContextScaleCTM(bsContext, scalingFactor, scalingFactor);
    [self drawControl];
    [NSGraphicsContext restoreGraphicsState];

    CGImageRef bsImage = CGBitmapContextCreateImage(bsContext);
    CGContextRelease(bsContext);

    // ... then, draw the backing store on the right hand side
    CGContextRef ctx = NSGraphicsContext.currentContext.CGContext;
    CGContextSaveGState(ctx);
    CGContextScaleCTM(ctx, 1.0 / scalingFactor, 1.0 / scalingFactor);
    CGContextDrawImage(ctx, CGRectMake(120 * scalingFactor, 0, self.backingStore.width, self.backingStore.height), bsImage);
    CGContextRestoreGState(ctx);
}

- (void)drawControl {
    CGRect controlFrame = CGRectMake(20, 20, 100, self.frameHeightSlider.intValue);

    NSGraphicsContext *nsCtx = NSGraphicsContext.currentContext;
    CGContextRef ctx = nsCtx.CGContext;
    [NSGraphicsContext saveGraphicsState];
    CGContextSaveGState(ctx);

    if (self.controlType != Box) {
        CGContextTranslateCTM(ctx, 0, CGRectGetHeight(controlFrame));
        CGContextScaleCTM(ctx, 1, -1);
        CGContextTranslateCTM(ctx, 0, -CGRectGetHeight(controlFrame));
    }

    [self addSubview:self.control];
    if (self.controlType != Box)
        ((NSControl *)self.control).enabled = self.enabledCheckbox.state == NSControlStateValueOn;

    if (self.boudingRectsCheckbox.state == NSControlStateValueOn) {
        [[NSColor.redColor colorWithAlphaComponent:0.5] setFill];
        NSRectFillUsingOperation(controlFrame, NSCompositingOperationSourceOver);

        [[NSColor.yellowColor colorWithAlphaComponent:0.5] setFill];
        NSRectFillUsingOperation([self.control alignmentRectForFrame:controlFrame], NSCompositingOperationSourceOver);

        CGRect drawingBounds = CGRectMake(0,
                                          0,
                                          CGRectGetWidth(controlFrame),
                                          CGRectGetHeight(controlFrame));
        if (self.controlType != Box)
            drawingBounds = [((NSControl *)self.control).cell drawingRectForBounds:drawingBounds];

        [[NSColor.greenColor colorWithAlphaComponent:0.5] setFill];
        drawingBounds.origin.x += controlFrame.origin.x;
        drawingBounds.origin.y += controlFrame.origin.y;
        NSRectFillUsingOperation(drawingBounds, NSCompositingOperationSourceOver);
    }

    if ([self.control isKindOfClass:NSButton.class]) {
        NSButton *button = (NSButton *)self.control;
        [button highlight:self.pressedCheckbox.state == NSControlStateValueOn];
        button.state = self.onStateCheckbox.state;

        if (self.controlType == CheckBox || self.controlType == RadioButton)
            [button.cell drawInteriorWithFrame:controlFrame inView:self.control];
        else
            [button.cell drawBezelWithFrame:controlFrame inView:self.control];
    } else {
        if (self.controlType == ComboBox) {
            NSComboBox *cb = (NSComboBox *)self.control;
#if 0
            CGPoint buttonPoint = CGPointMake(controlFrame.size.width - 10,
                                                controlFrame.size.height / 2.0);
            if (self.pressedCheckbox.state == NSControlStateValueOn)
                [self.control.cell startTrackingAt:buttonPoint inView:self];
            else if (self.pressedCheckbox.state == NSControlStateValueOff)
                [self.control.cell stopTracking:buttonPoint at:buttonPoint inView:self.control mouseIsUp:YES];
#else
            NSComboBoxCell *cbCell = (NSComboBoxCell *)cb.cell;
            cbCell.buttonCell.highlighted = self.pressedCheckbox.state == NSControlStateValueOn;
#endif
        }
        if (self.controlType == Box) {
            self.control.frame = controlFrame;
            if (@available(macOS 10.14, *))
                [self.control displayRectIgnoringOpacity:self.control.bounds inContext:NSGraphicsContext.currentContext];
            else
                [self.control drawRect:controlFrame];
        } else {
            NSControl *control = (NSControl *)self.control;
            [control.cell drawWithFrame:controlFrame inView:self.control];
        }
    }

    if (self.controlType != Box) {
        if (self.focusRingCheckbox.state == NSControlStateValueOn) {
            NSSetFocusRingStyle(NSFocusRingOnly);
            CGContextBeginTransparencyLayerWithRect(ctx, controlFrame, nil);
            NSControl *control = (NSControl *)self.control;
            control.cell.showsFirstResponder = YES;
            [control.cell drawFocusRingMaskWithFrame:controlFrame inView:self.control];
            CGContextEndTransparencyLayer(ctx);
        } else {
            [self.control drawFocusRingMask];
        }
    }

    CGContextRestoreGState(ctx);
    [NSGraphicsContext restoreGraphicsState];

    [self.control removeFromSuperviewWithoutNeedingDisplay];
}

- (IBAction)redraw:(id)sender {
    [self.frameHeightText takeIntValueFrom:self.frameHeightSlider];
    self.needsDisplay = YES;
}

- (IBAction)controlTypeSelected:(NSPopUpButton *)sender {
    const NSControlSize oldControlSize = self.controlSize;
    self.controlType = sender ? [sender indexOfItem:sender.selectedItem] : Button;
    if (self.controlType == Box) {
        NSBox *box = [[CustomNSBox alloc] init];
        self.control = box;
    } else if (self.controlType == ComboBox) {
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
    
    self.controlSize = oldControlSize;
    if (self.controlType != Box) {
        NSControl *control = (NSControl *)self.control;
        control.controlSize = self.controlSize;
    }

    [self redraw:sender];
}

- (IBAction)controlSizeSelected:(NSButton *)sender {
    if (self.controlType == Box)
        return;

    if (!self.control)
        [self controlTypeSelected:nil];

    NSControl *control = (NSControl *)self.control;
    
    switch (sender.tag) {
        case 0:
            control.controlSize = NSControlSizeRegular;
            break;
        case 1:
            control.controlSize = NSControlSizeSmall;
            break;
        case 2:
            control.controlSize = NSControlSizeMini;
            break;
        default:
            break;
    }

    [self redraw:sender];
}

@end
