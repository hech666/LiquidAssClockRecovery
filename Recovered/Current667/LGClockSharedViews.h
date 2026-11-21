#pragma once
#import <UIKit/UIKit.h>

// LiquidAss 6.6.7 arm64e — reconstructed from class metadata and code.
@interface LGVibranceView : UIView
- (instancetype)initWithFrame:(CGRect)frame;
- (instancetype)initWithFrame:(CGRect)frame
                   saturation:(CGFloat)saturation
                     contrast:(CGFloat)contrast;
@property (nonatomic) CGFloat brightness;
@property (nonatomic) CGFloat captureScale;
- (void)applyFilters;
- (void)updateShapeForBounds:(CGRect)bounds;
- (void)updateShapeWithScale:(CGFloat)scale
                   stretchX:(CGFloat)stretchX stretchY:(CGFloat)stretchY
                     shiftX:(CGFloat)shiftX shiftY:(CGFloat)shiftY;
@end

@interface LGBlurView : UIView
- (instancetype)initWithFrame:(CGRect)frame blurRadius:(CGFloat)blurRadius;
@property (nonatomic) BOOL followsSurfaceLiquidity;
@property (nonatomic) CGFloat cornerRadius;
@property (nonatomic) CGFloat blurRadius;
@property (nonatomic) CGFloat qualityScale;
@property (nonatomic) BOOL capturesAppIcon;
- (void)applyFilters;
@end
