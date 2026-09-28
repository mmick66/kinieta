# Changelog

All notable changes to Kinieta are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `Engine.shared.preferredFrameRateRange` sets the frame rates the engine asks
  the display for; it applies from the next frame, even mid-animation. The
  default, `Engine.defaultFrameRateRange`, is 30–120 Hz preferring 120 (1.0
  asked for 60–120 Hz), so the system can drop below 60 Hz to save power or
  under thermal pressure. Invalid ranges are ignored with a warning. The
  example app has a 60/120 Hz toggle.
- Debug builds log a warning, with the file and line of the call, for every
  chain call that is ignored: easing that follows no animation, `delay`,
  `onComplete` or easing with no unstarted action, `then` or `parallel()` with
  nothing to gather, `repeat(times:)` with zero or fewer times or an empty
  timeline, and `animate` on a group handle. They use the `Kinieta` subsystem,
  category `Chain`; release builds log nothing. See "Troubleshooting" in the
  README. The chain methods take `file:` and `line:` default arguments for this.
- tvOS 17 and Mac Catalyst 17 support. `Package.swift` declares both, the
  podspec declares tvOS (CocoaPods builds Catalyst from the iOS spec), and CI
  builds for tvOS and runs the tests on Mac Catalyst. The snapshot suite stays
  iOS only.
- Snapshot tests with swift-snapshot-testing: every property at five
  progress points, the three colour paths at their midpoint, transparent and
  grey endpoints, an overshooting curve, and dynamic colours in light and
  dark appearance. 72 reference images, 57 tests in total.

### Changed

- Reduce Motion now snaps only movement: `.x`, `.y`, `.width`, `.height`,
  `.frame` and `.rotation` jump to their end state, while `.alpha`, colours,
  `.borderWidth` and `.cornerRadius` still animate over the full duration, as
  Apple's Human Interface Guidelines recommend. An animation with only
  movement in it still finishes on its first frame. Set
  `Engine.shared.reduceMotionBehavior = .snapAll` for 1.0's behaviour, which
  snapped every property. The example app shows the setting and can switch it.
- CocoaPods: this release, not 1.0.0, is the final podspec release. It is
  published to trunk before trunk becomes read-only in December 2026. Use
  Swift Package Manager.

### Deprecated

- The `UIColor` helpers vendored from HandyUIKit: `ChangeableColorComponent`,
  `change(_:by:)`, `change(_:to:)`, `hlca`, `hsba`, `rgba` and
  `init(hue:luminance:chroma:alpha:)`. They were never part of Kinieta's API
  and clash with HandyUIKit itself. They are removed in 2.0.
- `UIColor.Components`, which was public but had no public members. It is
  removed in 2.0. See "Replacing the deprecated colour helpers" in the DocC
  catalog.

### Fixed

- The deprecated `change(.alpha, to:)` no longer shifts the colour: it sets
  the alpha directly instead of going through LCH.
- `Easing.inOut(.sine)` used the `inOut(.quad)` curve. It now uses Ceaser's
  easeInOutSine, `Bezier(0.445, 0.05, 0.55, 0.95)`.
- `onComplete`, `delay` and `repeat` on a `Kinieta.group` handle
  were silently dropped; the group is now an ordinary step of the handle's
  timeline. `animate` on a group handle, which has no view, is ignored with a
  warning in debug builds instead of finishing instantly.
- A colour with no RGB value, such as `UIColor(patternImage:)`, was read as
  transparent, so animating to or from it faded instead. It now switches as
  the animation starts, with a logged warning.
- LCH interpolation from a near-grey, such as `.secondaryLabel`, swept through
  unrelated hues. Hue is now weighted by chroma, so it heads straight for the
  other colour's hue; colours with chroma of 20 or more are unaffected.
- The podspec shipped no privacy manifest; CocoaPods consumers now get
  `PrivacyInfo.xcprivacy` in a `Kinieta_Privacy` resource bundle. Its
  description, still the Swift 4 one, now matches the README. There is no
  1.0.1: the fix reaches CocoaPods with this release.

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
