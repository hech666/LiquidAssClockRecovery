// LiquidAss 6.6.7 — LGClockReplacementTimeView, recovered from arm64e.
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#if !__has_feature(objc_arc)
#error LGClockReplacementTimeView.m requires ARC (-fobjc-arc).
#endif

// Declaration only. Use the real LGClockGlassView header when integrating it.
@interface LGClockGlassView : UIView
- (void)invalidateField;
@end

@interface LGClockReplacementTimeView : UIView
@property (nonatomic, weak) UILabel *stockLabel;
@property (nonatomic) BOOL stockHidden;
@property (nonatomic, weak) UIView *stockTimeView;
@property (nonatomic) BOOL stockTimeHidden;
@property (nonatomic, weak) UIView *stockDateView;
@property (nonatomic) CGRect stockDateFrame;
@property (nonatomic, copy) NSString *renderedText;
@property (nonatomic) double renderedHeight;
@property (nonatomic) double renderedMaximumHeight;
@property (nonatomic) double renderedWidth;
@property (nonatomic) double renderedTop;
@property (nonatomic) double renderedWeight;
@property (nonatomic) double renderedSoftness;
@property (nonatomic, strong) LGClockGlassView *glass;

- (void)restoreStockContent;
@end

@implementation LGClockReplacementTimeView {
    BOOL _stockHidden;
    BOOL _stockTimeHidden;
    __weak UILabel *_stockLabel;
    __weak UIView *_stockTimeView;
    __weak UIView *_stockDateView;
    NSString *_renderedText;
    double _renderedHeight;
    double _renderedMaximumHeight;
    double _renderedWidth;
    double _renderedTop;
    double _renderedWeight;
    double _renderedSoftness;
    LGClockGlassView *_glass;
    CGRect _stockDateFrame;
}

@synthesize stockLabel = _stockLabel;
@synthesize stockHidden = _stockHidden;
@synthesize stockTimeView = _stockTimeView;
@synthesize stockTimeHidden = _stockTimeHidden;
@synthesize stockDateView = _stockDateView;
@synthesize stockDateFrame = _stockDateFrame;
@synthesize renderedText = _renderedText;
@synthesize renderedHeight = _renderedHeight;
@synthesize renderedMaximumHeight = _renderedMaximumHeight;
@synthesize renderedWidth = _renderedWidth;
@synthesize renderedTop = _renderedTop;
@synthesize renderedWeight = _renderedWeight;
@synthesize renderedSoftness = _renderedSoftness;
@synthesize glass = _glass;

// 0x5f4b4
+ (Class)layerClass {
    return [CAShapeLayer class];
}

// 0x5f4c0: fetch each saved value before fetching its target view.
- (void)restoreStockContent {
    BOOL stockHidden = self.stockHidden;
    [self.stockLabel setHidden:stockHidden];

    BOOL stockTimeHidden = self.stockTimeHidden;
    [self.stockTimeView setHidden:stockTimeHidden];

    CGRect stockDateFrame = self.stockDateFrame;
    [self.stockDateView setFrame:stockDateFrame];
}

// 0x5f5a8: preserve both getter sends. ARC emits the super call and
// the ivar cleanup in .cxx_destruct (0x5f878).
- (void)dealloc {
    [self.glass invalidateField];
    [self.glass removeFromSuperview];
    [self restoreStockContent];
}
@end
