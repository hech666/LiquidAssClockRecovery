# LGClockGlassView recovery evidence and limits

Current-binary-derived files: `LGClockGlassView.h/.m` and `LGClockSharedViews.h/.m`. These are a semantic source reconstruction assembled from Objective-C metadata, runtime type encodings, PDG and raw ARM64e instructions; they are not original source text.

## Method scope

- `LGClockRefractionView +layerClass` (`0x87540`) and `LGClockGlassView` methods from init (`0x87580`) through `.cxx_destruct` (`0x8bc34`): field ownership and orientation, view layout, color/appearance, glyph-mask path and deferred publishing, digit transition, invalidation/readiness, and geometry diagnostics.
- `LGVibranceView` (`0x8eeec–0x8f73c`): backdrop-layer setup, saturation/contrast/brightness filters, and geometry updates.
- `LGBlurView` (`0x8f864–0x900cc`): backdrop filter setup, blur radius and capture/quality flags.
- The current analysis of `LGClockGlassView` compiled with local Clang 22 and iPhoneOS 16.5 SDK for arm64 and arm64e using `-Wall -Wextra -Werror`; after adding all six modules, public Actions is set to repeat the object build for both architectures.

## Evidence-based pieces versus reconstruction choices

The exact Objective-C method list and encodings are in `main_analysis/ClockInterfaces.h` and `clock_method_types.json`. The implementation maintains the observed `fieldReady` gating, field generation/consumption handshake, deferred glyph publication, editor/poster mapping selection, and layout/mask separation. Raw assembly should be treated as authoritative whenever it differs from the Ghidra pseudocode, especially for `updateFieldOrientation` and the field-publication blocks.

Distance-field generation, field layout labels, CAFilter configuration and the `LGBlurView`/`LGVibranceView` behaviors are human semantic translations, not verified byte-for-byte matches. Only object compilation is currently asserted. Private `CABackdropLayer`, `CAFilter` and KVC attributes have not been runtime-tested.

## Not yet linkable as the current 6.6.7 module

- `LGClockFieldMapping.m` still declares external `LGRecoveredResolveJBPath`; there is no source-level implementation of the current binary path resolver in the public project. It must be resolved before linking.
- `LGClockGlassView` currently composes with the legacy public `LGLiveBackdropView` interface/implementation. The exact 6.6.7 shared renderer changes and runtime methods such as native blur overrides need independent recovery. Do not ship this new glass implementation with the legacy renderer as if it were proven compatible.
- `LGClockReplacementTimeView` allocation and update happen in the larger worker at `0x64aa4`, whose full source is not recovered. No current-binary hook calls this reconstructed class yet.
- Source files are not installed in the current `.deb`; only the legacy baseline is packaged. There has been no iOS runtime or visual testing.
