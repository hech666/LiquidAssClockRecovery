// LiquidAss 6.6.7 arm64e — semantic recovery, not original source.
#import "LGClockSharedViews.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#include <math.h>

// Supplied by the shared glass preference implementation (arm64e 0x99180).
extern id LGGlassPreferenceValue(NSString *key);

static const CGFloat LGFilterEpsilon = 0.001; // __const 0xbd2e8

static Class LGClockBackdropLayerClass(void) {
    return NSClassFromString(@"CABackdropLayer") ?: CALayer.class;
}

static id LGClockNewCAFilter(Class filterClass, SEL factory, NSString *name) {
    return ((id (*)(id, SEL, NSString *))objc_msgSend)(filterClass, factory, name);
}

// Local translation of LGVibranceFilters (0x8ecac). The constant type array
// at 0xdf0f0 orders saturation before contrast. A bad inputAmount key does
// not prevent adding the created filter; a bad factory skips that entry.
static NSArray *LGClockVibranceFilters(CGFloat saturation, CGFloat contrast) {
    Class filterClass = NSClassFromString(@"CAFilter");
    if (!filterClass) return nil;

    NSMutableArray *filters = [NSMutableArray array];
    NSArray *types = @[@"colorSaturate", @"colorContrast"];
    NSArray *amounts = @[@(saturation), @(contrast)];
    for (NSUInteger i = 0; i < types.count; ++i) {
        @try {
            id filter = LGClockNewCAFilter(filterClass, NSSelectorFromString(@"filterWithType:"), types[i]);
            if (!filter) continue;
            @try {
                [filter setValue:amounts[i] forKey:@"inputAmount"];
            } @catch (__unused NSException *exception) {
            }
            [filters addObject:filter];
        } @catch (__unused NSException *exception) {
        }
    }
    return filters;
}

// Local translation of LGBlurRadiusWithLiquidity (0x8bf3c). Keep the
// preference lookup external: it owns the current build's preference cache.
static CGFloat LGClockBlurRadiusWithLiquidity(CGFloat radius) {
    id value = LGGlassPreferenceValue(@"Global.Liquidity");
    CGFloat liquidity = [value respondsToSelector:@selector(doubleValue)] ? [value doubleValue] : 0.7;
    if (!isfinite(liquidity)) liquidity = 0.7;
    return radius * fmin(fmax(liquidity, 0.1), 2.0);
}

@implementation LGVibranceView {
    CGSize _baseSize;
    CGFloat _saturation;
    CGFloat _contrast;
    CGFloat _brightness;
    NSArray *_filters;
    BOOL _backdropConfigured;
    CGFloat _captureScale;
}

@synthesize captureScale = _captureScale; // getter 0x8f72c

+ (Class)layerClass { // 0x8eeec
    return LGClockBackdropLayerClass();
}

- (instancetype)initWithFrame:(CGRect)frame { // 0x8ef2c
    return [self initWithFrame:frame saturation:1.85 contrast:1.06];
}

- (instancetype)initWithFrame:(CGRect)frame // 0x8ef40
                   saturation:(CGFloat)saturation
                     contrast:(CGFloat)contrast {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    _baseSize = frame.size;
    _saturation = saturation;
    _contrast = contrast;
    _captureScale = 1.0;
    self.userInteractionEnabled = NO;
    self.backgroundColor = UIColor.clearColor;
    self.opaque = NO;
    self.clipsToBounds = YES;
    self.layer.cornerRadius = frame.size.height * 0.5;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    [self applyFilters];
    return self;
}

- (void)didMoveToWindow { // 0x8f0b0
    [super didMoveToWindow];
    [self applyFilters];
}

- (void)layoutSubviews { // 0x8f0fc
    [super layoutSubviews];
    [self applyFilters];
}

- (CGFloat)brightness { // 0x8f148
    return _brightness;
}

- (void)setCaptureScale:(CGFloat)captureScale { // 0x8f158
    if (!isfinite(captureScale) || captureScale <= 0) return;
    if (!(fabs(_captureScale - captureScale) >= LGFilterEpsilon)) return;
    _captureScale = captureScale;
    _backdropConfigured = NO;
    [self applyFilters];
}

- (void)setBrightness:(CGFloat)brightness { // 0x8f1e8
    if (!(fabs(_brightness - brightness) >= LGFilterEpsilon)) return;
    _brightness = brightness;
    _filters = nil;
    [self applyFilters];
}

- (void)applyFilters { // 0x8f258
    Class backdropClass = NSClassFromString(@"CABackdropLayer");
    if (!backdropClass || ![self.layer isKindOfClass:backdropClass]) return;

    @try {
        if (!_backdropConfigured) {
            [self.layer setValue:@NO forKey:@"layerUsesCoreImageFilters"];
            [self.layer setValue:@YES forKey:@"windowServerAware"];
            [self.layer setValue:@(_captureScale) forKey:@"scale"];
            _backdropConfigured = YES;
        }
        if (!_filters.count) {
            NSMutableArray *filters = [LGClockVibranceFilters(_saturation, _contrast) mutableCopy];
            if (fabs(_brightness) > LGFilterEpsilon) {
                Class filterClass = NSClassFromString(@"CAFilter");
                if (filterClass) {
                    id brightness = LGClockNewCAFilter(filterClass, NSSelectorFromString(@"filterWithType:"), @"colorBrightness");
                    if (brightness) {
                        [brightness setValue:@(_brightness) forKey:@"inputAmount"];
                        [filters addObject:brightness];
                    }
                }
            }
            _filters = [filters copy];
        }
        if (_filters.count && ![self.layer.filters isEqualToArray:_filters]) {
            self.layer.filters = _filters;
        }
    } @catch (__unused NSException *exception) {
    }
}

- (void)updateShapeForBounds:(CGRect)bounds { // 0x8f590
    _baseSize = bounds.size;
    self.frame = bounds;
    [self updateShapeWithScale:1 stretchX:1 stretchY:1 shiftX:0 shiftY:0];
}

- (void)updateShapeWithScale:(CGFloat)scale // 0x8f5ec
                   stretchX:(CGFloat)stretchX stretchY:(CGFloat)stretchY
                     shiftX:(CGFloat)shiftX shiftY:(CGFloat)shiftY {
    CGSize base = self.superview ? self.superview.bounds.size : _baseSize;
    CGFloat width = base.width > 0 ? base.width : 60;
    CGFloat height = base.height > 0 ? base.height : 60;
    self.bounds = CGRectMake(0, 0, width * scale * stretchX, height * scale * stretchY);
    self.center = CGPointMake(fma(width, 0.5, shiftX), fma(height, 0.5, shiftY));
    self.layer.cornerRadius = CGRectGetHeight(self.bounds) * 0.5;
}

// ARC emits .cxx_destruct (0x8f73c in the input), releasing _filters.
@end

@implementation LGBlurView {
    id _blurFilter;
    CGFloat _appliedBlurRadius;
    BOOL _backdropConfigured;
    BOOL _followsSurfaceLiquidity;
    BOOL _capturesAppIcon;
    CGFloat _cornerRadius;
    CGFloat _blurRadius;
    CGFloat _qualityScale;
}

@synthesize followsSurfaceLiquidity = _followsSurfaceLiquidity; // getter 0x9005c
@synthesize cornerRadius = _cornerRadius; // getter 0x9006c
@synthesize blurRadius = _blurRadius; // getter 0x9007c
@synthesize qualityScale = _qualityScale; // getter/setter 0x9008c/0x9009c
@synthesize capturesAppIcon = _capturesAppIcon; // getter/setter 0x900ac/0x900bc

+ (Class)layerClass { // 0x8f864
    return LGClockBackdropLayerClass();
}

- (instancetype)initWithFrame:(CGRect)frame blurRadius:(CGFloat)blurRadius { // 0x8f8a4
    self = [super initWithFrame:frame];
    if (!self) return nil;
    _blurRadius = blurRadius;
    _qualityScale = 0.35;
    @try {
        [self.layer setValue:@YES forKey:@"ignoresScreenClip"];
    } @catch (__unused NSException *exception) {
    }
    self.userInteractionEnabled = NO;
    self.backgroundColor = UIColor.clearColor;
    self.opaque = NO;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    [self applyFilters];
    return self;
}

- (void)setCornerRadius:(CGFloat)cornerRadius { // 0x8f9ec
    _cornerRadius = cornerRadius;
    self.layer.cornerRadius = cornerRadius;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.layer.masksToBounds = YES;
}

- (void)didMoveToWindow { // 0x8faac
    [super didMoveToWindow];
    [self applyFilters];
}

- (void)layoutSubviews { // 0x8faf8
    [super layoutSubviews];
    [self applyFilters];
}

- (void)setBlurRadius:(CGFloat)blurRadius { // 0x8fb44
    if (fabs(_blurRadius - blurRadius) <= 0.01) return;
    _blurRadius = blurRadius;
    [self applyFilters];
}

- (void)setFollowsSurfaceLiquidity:(BOOL)followsSurfaceLiquidity { // 0x8fb70
    if (_followsSurfaceLiquidity == followsSurfaceLiquidity) return;
    _followsSurfaceLiquidity = followsSurfaceLiquidity;
    [self applyFilters];
}

- (void)applyFilters { // 0x8fb90
    Class backdropClass = NSClassFromString(@"CABackdropLayer");
    if (!backdropClass || ![self.layer isKindOfClass:backdropClass]) return;

    @try {
        if (self.blurRadius <= 0) {
            if (self.layer.filters.count) self.layer.filters = nil;
            return;
        }
        if (!_backdropConfigured) {
            [self.layer setValue:@NO forKey:@"layerUsesCoreImageFilters"];
            [self.layer setValue:@YES forKey:@"windowServerAware"];
            if (![self.layer valueForKey:@"groupName"]) {
                [self.layer setValue:[NSUUID UUID].UUIDString forKey:@"groupName"];
            }
            _backdropConfigured = YES;
        }

        CGFloat radius = self.followsSurfaceLiquidity
            ? LGClockBlurRadiusWithLiquidity(self.blurRadius) : self.blurRadius;
        if (!_blurFilter || fabs(_appliedBlurRadius - radius) > LGFilterEpsilon) {
            Class filterClass = NSClassFromString(@"CAFilter");
            SEL factory = NSSelectorFromString(@"filterWithName:");
            if (!filterClass || ![filterClass respondsToSelector:factory]) return;
            id filter = LGClockNewCAFilter(filterClass, factory, @"gaussianBlur");
            if (!filter) return;
            [filter setValue:@(radius) forKey:@"inputRadius"];
            [filter setValue:@YES forKey:@"inputNormalizeEdges"];
            _blurFilter = filter;
            _appliedBlurRadius = radius;
        } else if (self.layer.filters.count == 1 && self.layer.filters.firstObject == _blurFilter) {
            return;
        }
        self.layer.filters = @[_blurFilter];
    } @catch (__unused NSException *exception) {
    }
}

// ARC emits .cxx_destruct (0x900cc in the input), releasing _blurFilter.
@end
