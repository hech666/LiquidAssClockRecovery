/* Human semantic translation, arm64e 0x5ffc4-0x60084.
 * Replace LGClockEditorState's existing method when integrating.
 * A category here documents the recovered method; this is not a full class.
 * The binary uses a fused multiply-add for the final expression.
 */
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#include <math.h>
@interface LGClockEditorState : NSObject
@property(nonatomic) BOOL widgetPickerLayout;
@property(nonatomic) BOOL clockAnimating;
@property(nonatomic) double progress;
@property(nonatomic) double clockAnimationStart;
@property(nonatomic) double clockAnimationFrom;
@end
@implementation LGClockEditorState (RecoveredProgress)
- (double)displayProgress {
    double target = self.widgetPickerLayout ? 0.0 : self.progress;
    if (!self.clockAnimating) return target;
    double t = fmax((CACurrentMediaTime() - self.clockAnimationStart) / 0.42, 0.0);
    t = t > 1.0 ? 1.0 : t;
    if (t >= 1.0) self.clockAnimating = NO;
    double remaining = 1.0 - t;
    double delta = remaining * (self.clockAnimationFrom - target);
    delta *= remaining;
    return fma(delta, remaining, target);
}
@end
