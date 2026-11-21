#pragma once
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <stdint.h>

// 6.6.7 class_ro identifies this superclass. Override with the current shared
// header at integration time; the reference header supplies declarations only.
#import "../../Shared/LGLiveBackdropView.h"

@class LGBlurView, LGVibranceView;
struct LGClockField; // Shared mapping header; definition in the implementation.

@interface LGClockRefractionView : LGLiveBackdropView
+ (Class)layerClass; // 0x87540
@end

@interface LGClockGlassView : UIView {
@private
    // Original arm64e ivar ordering, types and offsets; runtime may slide the
    // first ivar on a different OS. Field-struct member names are reconstructed.
    struct LGClockField *_mapping;              // 0x08
    uint64_t _producer, _firstGeneration;      // 0x10, 0x18
    CGPathRef _pendingPath;                    // 0x20 (owned CF reference)
    CGSize _pendingSize;                       // 0x28
    BOOL _pendingDeferred;                     // 0x38
    uint64_t _fieldEpoch;                      // 0x40
    BOOL _busy, _invalidated;                  // 0x48, 0x49
    uint64_t _publishedCount;                  // 0x50
    LGVibranceView *_vibrance;                 // 0x58
    UIView *_material, *_colorTint;            // 0x60, 0x68
    CFTimeInterval _lastGeometryTrace;         // 0x70
    uint64_t _geometryTraceCount;              // 0x78
    CAShapeLayer *_glyphMask;                  // 0x80
    LGBlurView *_blur;                         // 0x88
    LGLiveBackdropView *_glass;                // 0x90
    BOOL _editor;                             // 0x98
    NSInteger _posterSlot;                    // 0xa0
    CAShapeLayer *_clockSpecular;              // 0xa8
    LGVibranceView *_specularVibrance;         // 0xb0
    NSArray *_digitPaths;                     // 0xb8
    NSString *_digitText;                     // 0xc0
    uint64_t _digitTransition;                // 0xc8
    UIColor *_clockColor;                     // 0xd0
}
@property (nonatomic, readonly) BOOL fieldReady;
@property (nonatomic, strong) UIColor *clockColor;
- (instancetype)initWithFrame:(CGRect)frame;
- (void)ensureFieldOwnership;
- (void)logClockGeometry:(NSString *)reason;
- (void)layoutSubviews;
- (void)updateFieldOrientation;
- (void)refreshAppearance;
- (void)invalidateField;
- (void)dealloc;
- (void)setGlyphPath:(CGPathRef)path canvasSize:(CGSize)size deferRendering:(BOOL)deferRendering;
// Element type inferred from CGPath calls on the indexed array elements.
- (void)transitionDigits:(NSArray *)paths text:(NSString *)text animated:(BOOL)animated;
- (void)publishPendingField;
// .cxx_destruct is emitted by ARC, not manually declared.
@end
