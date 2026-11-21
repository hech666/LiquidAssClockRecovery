# LiquidAss Clock Recovery

**Status: first cloud-buildable baseline; not yet a 6.6.7-equivalent restoration.** This repository currently compiles a time-only tweak based on the public LiquidAss 0.1.1-2b clock implementation. It is a bootstrap for the ongoing recovery, not a claim that the newer LGClockReplacementTimeView/editor implementation has been fully reconstructed. Do not install this smoke-test package over a production setup yet.

## Build

GitHub Actions runs on `macos-15`, fetches Roothide Theos and iPhoneOS 16.5 SDK, and builds a thin arm64e package. Push to `main` or run Actions → Build workflow. The `.deb` is uploaded as an Actions artifact. Local command when Theos is installed:

```sh
sh build.sh roothide
```

The filter is SpringBoard only. This avoids injecting clock hooks into unrelated UIKit applications. The package conflicts with `haoge.liquidass` to prevent duplicate hooks.

## Included baseline

- `Hooks/Clock.x`: public older time/date hook, variable-font axis handling, mask generation, layout avoidance and animation.
- `LiquidAssBackboardd/`: older public Backboardd renderer that consumes the shared clock glyph mask and uploads it to the Metal pipeline. The renderer is generic and still contains support code for other host types; it is an untrimmed shared dependency, not a 6.6.7 backend reconstruction.
- `Shared/`: shared material renderer, preference and utility code required by those sources. `LGHostRegistry.h` retains common host definitions because the shared view implementation references those enum constants; only the Clock SpringBoard hook and Backboardd renderer targets are installed.
- `LICENSE`, `NOTICES.md`, `REFERENCE.md`: upstream attribution and CC BY-NC 4.0 terms for the public reference. The reference commit is `3656bb1d3f09d3e1ed7ea5132ddf04a270934ea8` (`winaviation-tweaks/liquidass`, public 0.1.1-2b source).

The settings UI, modern replacement-time/editor classes, exact 6.6.7 hooks, and complete clock rendering/backend integration remain under reconstruction. The font file is intentionally omitted from this public repo because its redistribution license has not been established; the old clock source falls back if the optional font is absent. Add a legally redistributable font at `layout/Library/PreferenceBundles/LiquidAssPrefs.bundle/SFAdaptiveSoftNumeric-VF.otf` only after confirming rights.

## Recovery materials

The original uploaded 6.6.7 deb was analyzed separately; no original binary is included here. Function-level metadata and static pseudocode are not original source. Each newly ported method must be checked against the disassembly and then built by Actions. Until the remaining 6.6.7 behavior is ported, this repo must not be represented as a complete source recovery.

## License

Upstream-derived files remain under the source project's CC BY-NC 4.0 license and notices. New recovery/build glue is attributed to hech666 in the commit history. Font assets are excluded pending separate license review.
