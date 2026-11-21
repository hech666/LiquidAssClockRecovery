# 6.6.7 module recovery status

These six source reconstructions from the uploaded 6.6.7 arm64e image are compiled as standalone objects for arm64 and arm64e with iPhoneOS 16.5 SDK and ARC. They are not linked into the `.deb`; the installable package still uses the attributed 0.1.1-2b clock baseline. Object compilation is not proof of runtime equivalence.

- `LGClockReplacementTimeView.m`: property storage, stock-content restoration, layer class, deallocation. Its creation/update worker `0x64aa4` is not yet ported into the running hook.
- `LGClockGlassView.m/.h`: shape, glyph path, glass, field publication and invalidation reconstruction. It composes with the legacy public `LGLiveBackdropView` interface and `LGClockSharedViews`.
- `LGClockSharedViews.m/.h`: reconstructed blur and vibrance child classes. These rely on private QuartzCore `CABackdropLayer`, `CAFilter`, and KVC keys at runtime.
- `LGClockFieldMapping.m`: editor/poster memory mapping translation. It has unresolved `LGRecoveredResolveJBPath`; it cannot be linked until the current path resolver and correct sandbox behavior are supplied.
- `LGClockProgressRecovery.m`: one editor progress interpolation method, not the full editor state implementation.
- `LGClockSettings.m`: readable translation of the clock settings keys and defaults; no Preference bundle UI is reconstructed.
- `LGClockReplacementTimeView.evidence.md`: method/type evidence for that class.

All inferred behavior and unresolved details remain marked in comments or evidence. No current-module integration or device test has been done. Do not install the baseline package expecting 6.6.7 feature parity.
