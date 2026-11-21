# LGClockReplacementTimeView — 6.6.7 recovery evidence

## Confirmed from the binary

| Entry point (arm64e VA) | Recovered behavior and evidence |
| --- | --- |
| `+layerClass` (`0x5f4b4`, adjacent to the requested instance range) | Returns `[CAShapeLayer class]`. `asm/0005f4b4.asm` loads the class reference at `0xec4d0` and branches to `objc_opt_class`; the relocation names `CAShapeLayer`. |
| `-restoreStockContent` (`0x5f4c0`) | In order: read `stockHidden` then `stockLabel` and send `setHidden:`; read `stockTimeHidden` then `stockTimeView` and send `setHidden:`; read `stockDateFrame` then `stockDateView` and send `setFrame:`. No explicit guard, reparenting, or field reset. `asm/0005f4c0.asm` and `objc_stubs.json` resolve the six getter calls (`0xb0260`–`0xb0300`); the four `CGRect` components pass through `d0`–`d3`, which the PDG does not model correctly. |
| `-dealloc` (`0x5f5a8`) | Fetches `glass` and sends `invalidateField`, fetches `glass` again and sends `removeFromSuperview` (`0xab200`), then sends `restoreStockContent` (`0xab660`) to `self` before super deallocation. `asm/0005f5a8.asm` and `objc_stubs.json` resolve the sequence; `0xec238` points to the `dealloc` selector. |
| Accessors (`0x5f630`–`0x5f864`) and `.cxx_destruct` (`0x5f878`) | The property list at `0xe2908` records 14 nonatomic properties. The stock label (`UILabel *`) and time/date views (`UIView *`) are weak; the saved flags are `BOOL`, and the date frame is `CGRect`. Rendered text is copied (`NSString *`), the six numeric render fields encode as `d`, and `glass` is strong (`LGClockGlassView *`). The accessors and destructor corroborate the ownership flags. |

Evidence paths above are relative to `main_analysis/`. The selector inventory and types are in `clock_method_types.json` and `ClockInterfaces.h`; concrete object types and ownership come from the class's property and ivar records, not from the method encoding `@` alone.

## Source choices and unresolved entry points

- The original source spelling is not recoverable. This version uses `double` for `d` (any original typedef is unknown), explicit saved-value locals to preserve message order, and synthesized ARC accessors. ARC emits `.cxx_destruct` and the super `dealloc` call; neither is a handwritten method here.
- No class-local selector remains unresolved. Outside this class, `-[LGClockGlassView invalidateField]` (`0x89250`) is a real runtime dependency, declared but not implemented here. Use the actual glass interface when integrating it. The caller at `0x64aa4` contains stock-reference setters and a `setGlyphPath:canvasSize:deferRendering:` send (`0x67b98`); the caller's full source, stock-state capture, and glyph generation are outside this recovery. No hooks were added.

## Build verification

Clang 19 with the iPhoneOS 16.5 SDK compiled the file to Mach-O objects for `arm64-apple-ios15.0` and `arm64e-apple-ios15.0` with `-fobjc-arc -Wall -Wextra -Werror -O2`. On both architectures, the emitted 32 method encodings, 14 property records, and 14 ivar records (including on-disk offsets) matched the 6.6.7 metadata. This was a local object build, not a GitHub Actions run or an on-device test.

For Theos integration, add this `.m` to the target's `_FILES`, enable `-fobjc-arc`, and link `UIKit` and `QuartzCore`. Do not compile another implementation of the same class into that target. No public repository or workflow was modified.
