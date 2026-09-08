# Changelog

All notable changes to Kinieta are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-09-08

The modernisation release. Swift 6, Swift Package Manager, iOS 17 and up.

### Added

- Typed `Property` enum for everything that can be animated.
- `Kinieta` handles with `cancel()`, `pause()`, `resume()`, `state` and
  `await finished()`.
- `Kinieta.group(_:completion:)` runs several timelines together and returns
  a handle for all of them.
- `ColorInterpolation` (`.rgb`, `.hsb`, `.lch`) per property or as the engine
  default. Hue takes the shorter arc in `.hsb` and `.lch`.
- Reduce Motion support: animations snap to their end state, pauses keep
  their timing. `Engine.shared.respectsReduceMotion` opts out.
- The engine requests 120 Hz on ProMotion displays.
- Swift Package Manager manifest, privacy manifest, DocC catalog, GitHub
  Actions CI, Swift Testing suite. Sources are guarded with `canImport(UIKit)`
  so the package builds as an empty module on non-UIKit hosts.
- Example app on the UIScene lifecycle with an easing and colour gallery.

### Changed

- **Breaking:** the string-dictionary API (`move(to: ["x": 1])`) is replaced
  by `animate(.x(1))`. See the migration guide in the DocC catalog.
- **Breaking:** `Easing.Types` is `Easing.Curve` with lowerCamelCase cases;
  `.Custom(Bezier)` is `.custom(Bezier)`. `Easing` itself is a value with
  `.in`, `.out`, `.inOut`, `.custom` and `.linear`.
- **Breaking:** `wait(for:)`, `delay(for:)`, `again(times:)` and `complete`
  are `wait(_:)`, `delay(_:)`, `repeat(times:)` and `onComplete`.
- **Breaking:** `Engine.group` moved to `Kinieta.group`; `Defaults` is
  replaced by `Engine.shared.colorInterpolation`.
- Colours interpolate through LCH by default instead of RGB.
- Views are held weakly; a timeline never keeps its view alive.
- Minimum deployment target is iOS 17. Swift 6 language mode.
- Library and example app are separate: `Sources/Kinieta` and `Example/`.
- CocoaPods: 1.0.0 is the final podspec release. Use Swift Package Manager.

### Fixed

- Easing curves were evaluated at the Bézier parameter instead of at time,
  distorting every preset and custom curve.
- Time advanced by the nominal frame interval, so dropped frames slowed
  animations instead of catching up.
- HCL-assisted colour interpolation stopped at 80% of the way to the target.
- `cornerRadius` animated `borderWidth`.
- A sequence never fired its own completion block.
- `then` reversed the order of the actions it sealed.
- Moving or resizing a rotated view sent it off screen.
- Zero-duration animations skipped their completion block.
- An overshooting easing on a colour animation hit a `fatalError`.
- Cancelling a handle that had been passed to a group did nothing.
- Easing applied after `delay` was silently dropped.
- Colour animations ended on a frozen colour, losing Dark Mode adaptation
  and wide gamut; the target is now assigned exactly.
- Overshooting curves could drive width, height, border width or corner
  radius negative.
- Each action boundary in a sequence cost up to one frame; the unused part
  of a frame now carries into the next action.
- Custom Béziers with control x outside 0...1 solved to nonsense; x is
  clamped as in CSS.
- HSB interpolation from a grey swept through the hue wheel.
- Fading from `.clear` passed through black.
- The README grouping example did not compile.
- The podspec shipped the demo's app delegate into every consumer.

## [0.5.1] - 2017-11-09

Last Swift 4 release. Tagged `v0.5.1-legacy`.
