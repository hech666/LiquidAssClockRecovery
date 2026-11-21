/* Human-readable reconstruction of the time controls found in the 6.6.7
 * LiquidAssPrefs arm64 Mach-O at LGClockItems (0x1fae0).
 * UI dictionary builders/localization are intentionally not reimplemented.
 */
#import <UIKit/UIKit.h>

NSString * const LGRecoveredClockFPSKey = @"Clock.FPS";
NSString * const LGRecoveredClockDateFormatEnabledKey = @"Lockscreen.Clock.DateFormat.Enabled";
NSString * const LGRecoveredClockDateFormatKey = @"Lockscreen.Clock.DateFormat.Format";

NSInteger LGRecoveredDefaultClockFPS(UIScreen *screen) {
    NSInteger maximum = screen.maximumFramesPerSecond;
    return maximum > 0 ? maximum : 60;
}
NSInteger LGRecoveredMinimumClockFPS(void) { return 1; }
BOOL LGRecoveredDateFormatEnabledByDefault(void) { return YES; }
NSString *LGRecoveredDateFormatDefault(void) { return @""; }
NSString *LGRecoveredDateFormatPlaceholder(void) { return @"EEE MMM d"; }
