# Changelog

All notable changes to Kinieta are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `Bezier.progress(at:)` returns the eased progress at a time fraction, and
  `Bezier.Point(x:y:)` creates a control point with labelled coordinates, as
  `CGPoint` does.

- `repeatForever()` replays the whole chain so far, including the actions
  already running or done, until the handle is cancelled: a spinner, a
  pulsing badge or a breathing placeholder. The loop is one step holding one
  copy of the chain, so memory stays flat. `finished()` returns once the
  timeline is cancelled or its view deallocated, a group running it never
  completes, and completion blocks inside the chain run on every cycle. A
  cycle that takes no time, such as one of zero durations or one snapped by
  Reduce Motion, plays once per frame. In debug builds, a chain call made
  after `repeatForever()` logs a warning, since it could never run. The
  example app's Controls row has a Loop button.

- Experimental macOS support: on native macOS 14 and later, `NSView` gets
  `animate(_:duration:)` and `wait(_:)` with the full timeline API, for
  `.x`, `.y`, `.width`, `.height` and `.frame` (the view's frame),
  `.rotation` (`frameRotation`, about the view's centre and unwrapped),
  `.alpha` (`alphaValue`), `.borderWidth` and `.cornerRadius` (the layer's),
  and `.background` and `.borderColor` with an `NSColor` (the layer's colours,
  in sRGB or Display P3, with dynamic colours resolved against the view's
  effective appearance). The layer properties give a view without a layer one. Once a view is rotated,
  `.x`, `.y` and `.frame` stand for the frame it would have unrotated, so
  position, size and rotation animate independently, as on UIKit. Frames come
  from the display link of the screen the latest animated view's window is
  on, else the main screen's, and follow that window to another screen; with
  no screen at all a timer drives them, so animations still finish. `NSColor`
  and `CGColor` conform to `Interpolatable` on macOS too. `Property.custom(_:to:isMotion:)` takes key
  paths rooted in `NSView` or a subclass, such as `\.layer!.shadowOpacity` or
  `\NSBox.fillColor`, with colours interpolated like `.background`; a key path
  to `frameRotation` or `frameCenterRotation` shares `.rotation`'s key and
  counts as motion. `Property.constant(of:to:)` animates a constraint's constant
  with `layoutSubtreeIfNeeded()` on every frame. See "macOS (experimental)" in
  the README.
- The podspec declares macOS 14, and the example project has a
  `KinietaDemoMac` scheme: the gallery's easing, colour, timeline, Controls,
  Interrupting and Auto Layout rows on native macOS. CI builds it, and the
  DocC catalog builds for macOS without warnings and lists the platforms
  Kinieta supports.
- A newer animation of a property takes it over from an older one still
  running on the same view, like UIKit's `beginFromCurrentState`. It starts
  from the value on screen; the older animation stops writing that property,
  keeps animating the rest and runs its completion block on schedule. Before,
  both wrote the property every frame. `.frame` counts as `.x`, `.y`, `.width`
  and `.height`, and a `.constant` is matched by its constraint. See
  "Interrupting" in the README. In the example app, pressing Play again
  continues from where the views are, and an Interrupting row retargets a
  moving square.
- `Property.custom(_:to:isMotion:)` animates any writable key path of a
  view, such as `\.layer.shadowOpacity`, `\.tintColor` or
  `\UILabel.textColor`, to an `Interpolatable` value. Colours go through the
  engine's colour interpolation like `.background`. Pass `isMotion: true` to
  snap it under Reduce Motion.
- `Property.constant(of:to:)` animates an `NSLayoutConstraint`'s constant and
  lays out the constraint's views every frame, so a view placed by Auto Layout
  can animate without snapping back on the next layout pass. It snaps under
  Reduce Motion. The example app has an Auto Layout row that keeps playing
  through rotation.
- The public `Interpolatable` protocol, adopted by `CGFloat`, `Double`,
  `Float`, `CGPoint`, `CGSize`, `CGRect`, `CGAffineTransform`, `UIColor` and
  `CGColor` (both through LCH). Conform your own types to animate them with
  `.custom`.
- `.custom(\.transform, to:)` animates a view's `CGAffineTransform` the way
  Core Animation does: each end is decomposed into translation, rotation
  (the shorter way round), scale and shear, so a view keeps its size while it
  turns and a flip scales through zero. A transform key path counts as motion
  for Reduce Motion unless you pass `isMotion: false`. It writes the same
  transform as `.rotation`, so a newer one of either takes it over from an
  older one, including through a subclass key path such as
  `\UIImageView.transform`. A `CGColor` key path, such as
  `\.layer.shadowColor`, animates through the engine's colour interpolation
  like `.background`.
- `Engine.shared.preferredFrameRateRange` sets the frame rates the engine asks
  the display for; it applies from the next frame, even mid-animation. The
  default, `Engine.defaultFrameRateRange`, is 30–120 Hz preferring 120 (1.0
  asked for 60–120 Hz), so the system can drop below 60 Hz to save power or
  under thermal pressure. Invalid ranges are ignored with a warning. The
  example app has a 60/120 Hz toggle.
- Debug builds log a warning, with the file and line of the call, for every
  chain call that is ignored: easing that follows no animation, `delay`,
  `onComplete` or easing with no unstarted action, `then()` or `parallel()` with
  nothing to gather, `repeat(times:)` with zero or fewer times or an empty
  timeline, and `animate` on a group handle. They use the `Kinieta` subsystem,
  category `Chain`; release builds log nothing. See "Troubleshooting" in the
  README. The chain methods take `file:` and `line:` default arguments for this.
- tvOS 17 and Mac Catalyst 17 support. `Package.swift` declares both, the
  podspec declares tvOS (CocoaPods builds Catalyst from the iOS spec), and CI
  builds for tvOS and runs the tests on Mac Catalyst. The snapshot suite stays
  iOS only.
- visionOS 1 support. `Package.swift` declares it and CI runs the tests on
  the Apple Vision Pro simulator. `Engine.defaultFrameRateRange` is 30–100 Hz
  preferring 90 on visionOS, to fit its 90/96/100 Hz display.
- Snapshot tests with swift-snapshot-testing: every property at five
  progress points, the three colour paths at their midpoint, transparent and
  grey endpoints, an overshooting curve, and dynamic colours in light and
  dark appearance. 72 reference images, 57 tests in total.
- The example app has a Controls section: one handle built with `then()`,
  `parallel()`, `delay` and `repeat`, Play, Pause, Resume and Cancel buttons
  driving it, and a label set when `await finished()` returns.

- The library's types are also reachable through the `Kinieta` class:
  `Kinieta.Property`, `Kinieta.CustomProperty`, `Kinieta.Interpolatable`,
  `Kinieta.Easing`, `Kinieta.Bezier`, `Kinieta.ColorInterpolation`,
  `Kinieta.Engine` and `Kinieta.ReduceMotionBehavior`. A module with a type
  of its own named `Property`, `Easing` or `Engine` can name Kinieta's this
  way; module qualification cannot, because `Kinieta` names the class. See
  "Name clashes" in the README.
- `Kinieta.Completion`, `@MainActor () -> Void`: the type of the blocks passed
  to `onComplete(_:)` and `Kinieta.group(_:completion:)`. A stored
  `() -> Void` is still accepted.
- CI builds the library with `BUILD_LIBRARY_FOR_DISTRIBUTION=YES`, as an
  XCFramework is built. Its `.swiftinterface` only verifies with
  `OTHER_SWIFT_FLAGS=-alias-module-names-in-module-interface`, because the
  module and its main class share a name; without the flag the interface
  refers to `Kinieta.Property` and the like, which resolve to the class. See
  "Building an XCFramework" in the README.

### Changed

- `repeat(times:)` makes at most 10,000 copies and logs a warning when given
  more. Before, `repeat(times: .max)` built its copies on the main thread
  until the app hung. `Kinieta.wait(_:)` takes `file` and `line` parameters,
  with defaults, like the other chain calls, for its debug warning.
- `Property` has a new case, `extended(CustomProperty)`, which holds the
  properties made by `.custom` and `.constant`. A `switch` over `Property`
  that lists every case needs a `default` or the new case.
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
- Faster timelines. The preset easings are baked once and shared instead of
  per call, and timelines are built and run in linear time: a 10,000-step
  timeline builds and runs about 45 times faster (3.3 s to 0.07 s in a debug
  build on the iOS Simulator). Many timelines finishing on the same frame
  leave the engine in one pass, and so do the timelines `Kinieta.group` takes
  over and those a cancelled group cancels: grouping 10,000 timelines while
  10,000 others run, then cancelling the group, went from 43 s to 0.23 s.
- A handle can be extended at any time, not only while chaining. Adding to a
  finished handle starts it again on the next frame, its `state` goes back to
  `.running` and `finished()` waits for the new actions; a member of a
  `Kinieta.group` rejoins its group if the group is still running and
  otherwise runs on its own. A cancelled handle ignores further calls. See
  "Controlling a timeline" in the README.
- `repeat(times:)` copies the whole chain, including the actions already
  running or done. A finished timeline forgets its actions, so a `repeat`
  added after it finished copies only what was added since.
- Easing, `delay`, `onComplete`, `then()` and `parallel()` only reach actions
  that have not started yet; debug builds warn when one finds nothing to act
  on.
- Negative and NaN durations passed to `animate`, `wait` or `delay` are
  treated as zero and log a warning. `wait(.infinity)` and `delay(.infinity)`
  hold the timeline until it is cancelled; an infinite `animate` duration is
  treated as zero.
- A timeline belongs to at most one `Kinieta.group`. The group leaves out,
  with a logged warning, any timeline that is already in a group or has
  already finished or been cancelled, and runs a timeline listed twice once.

### Deprecated

- The `UIColor` helpers vendored from HandyUIKit: `ChangeableColorComponent`,
  `change(_:by:)`, `change(_:to:)`, `hlca`, `hsba`, `rgba` and
  `init(hue:luminance:chroma:alpha:)`. They were never part of Kinieta's API
  and clash with HandyUIKit itself. They are removed in 2.0.
- `UIColor.Components`, which was public but had no public members. It is
  removed in 2.0. See "Replacing the deprecated colour helpers" in the DocC
  catalog.
- The `then` property, renamed `then()`. Reading a property changed the
  timeline, so a second read, a `print` or the debugger could seal it again;
  the method is discardable and its warnings carry the file and line.
- `Easing.Curve.custom(Bezier)`. Use `Easing.custom(_:)`: the curve is used as
  given, so `.in(.custom(b))`, `.out(.custom(b))` and `.inOut(.custom(b))`
  silently ignored the placement.
- `Bezier.solve(_:)`, renamed `progress(at:)`, and `Bezier.Point(_:_:)`,
  replaced by `Point(x:y:)`. `curve.solve(0.3)` said neither what goes in nor
  what comes out. Both are removed in 2.0.
- The top-level `Block` typealias. It put a generic name in every client's
  namespace and did not say its blocks run on the main actor. Use
  `Kinieta.Completion`. It is removed in 2.0.
- Planned for 2.0: the module is renamed so that it no longer shares its name
  with the `Kinieta` class, which makes module qualification work and the
  alias flag above unnecessary, and `Block` is removed. `onComplete(_:)` and
  `Kinieta.group(_:completion:)` then take only a `Kinieta.Completion`.
  Whether the generic top-level names (`Property`, `Easing`, `Engine`,
  `Bezier`) also move under the class is decided with the rename.

### Fixed

- The example app lays out within the safe area, so in landscape the tracks
  no longer sit under the sensor housing, and a rotation mid-animation
  replays the gallery at the new size instead of leaving squares short of or
  past the end of their tracks.
- The deprecated `change(.alpha, to:)` no longer shifts the colour: it sets
  the alpha directly instead of going through LCH.
- `Easing.inOut(.sine)` used the `inOut(.quad)` curve. It now uses Ceaser's
  easeInOutSine, `Bezier(0.445, 0.05, 0.55, 0.95)`.
- `onComplete`, `delay` and `repeat` on a `Kinieta.group` handle
  were silently dropped; the group is now an ordinary step of the handle's
  timeline. `animate` on a group handle, which has no view, is ignored with a
  warning in debug builds instead of finishing instantly.
- Actions added to a handle whose timeline had finished never ran and nothing
  reported it, so a `Kinieta(for:)` handle built in a later run-loop turn did
  nothing. `repeat(times:)` called after the first frame dropped the action
  running at the time, and easing or `onComplete` added after the start could
  reach the wrong action. A finished timeline now also releases its
  completion blocks, so a block that captures its own handle no longer keeps
  it alive.
- A negative `wait` or `delay` fast-forwarded the next action to its end, and
  a NaN one never finished, so `finished()` never returned and the display
  link ran forever. A pause now never hands on more than the current frame.
- `cancel()` or `pause()` called from an `onComplete` block did not stop the
  timeline in that frame: the next action started with the frame's leftover
  time, and a cancelled timeline could end up `.finished`. They now take
  effect immediately at any depth of `then()`, `delay`, `parallel()` or
  `Kinieta.group`; the other members of a group are not advanced, and a
  cancelled timeline stays `.cancelled` and runs no further completion blocks.
- Cancelling a `Kinieta.group` handle left its members `.running` forever,
  with their `finished()` calls never returning; pausing it left them
  reporting `isRunning`. The group handle's `cancel()`, `pause()` and
  `resume()` now reach every member. A timeline grouped twice, or listed twice
  in one group, animated at double speed, and grouping a finished timeline
  ran its completion block again. Grouping no longer empties the engine for a
  moment, which reset its frame clock.
- `await finished()` now returns as soon as the awaiting task is cancelled.
  The timeline carries on, and other tasks awaiting it keep waiting.
- A timeline that was paused, or waiting on `wait(.infinity)`, when its
  handle was released stayed registered with the engine for the life of the
  process, holding its actions and completion blocks. Nothing could resume or
  cancel it, so the engine now lets go of it once nothing else is animating.
  A completion block that captures the handle still keeps it, and its
  timeline, alive.
- Releasing a paused group handle left the timelines in it stuck: their own
  handles reported `.paused`, then `.running` after `resume()`, but nothing
  drove them, so they never moved and their `finished()` never returned. The
  engine now takes them over, still paused, and `resume()` or `cancel()` on
  each handle works as it does outside a group.
- When a view was deallocated only its running animation stopped: a
  following `wait` still held the display link, later completion blocks ran
  and the handle ended `.finished`. The whole timeline is now cancelled
  before anything else in it runs, and the handle ends `.cancelled`. This
  includes a timeline that is paused, on its own or by its group, or waiting
  on `wait(.infinity)`, which gets no frames: it used to stay `.paused` or
  `.running`, with its `finished()` callers suspended, until something else
  animated. A view released from a completion block stops the timeline in
  that frame, as `cancel()` does, at any depth of `then()`, `delay` or
  `parallel()`: the rest of that step, including its own `onComplete`, no
  longer runs. A timeline with nothing left to run still ends `.finished`.
- The frames between dynamic colours, such as `.label`, were resolved
  against the app's traits rather than the view's, so a view with
  `overrideUserInterfaceStyle` or in a sheet of another appearance animated
  through the wrong variants and snapped to the right one at the end. They now
  resolve against the view's own traits, and again when its appearance
  changes mid-animation, such as Dark Mode being toggled.
- A colour with no RGB value, such as `UIColor(patternImage:)`, was read as
  transparent, so animating to or from it faded instead. It now switches as
  the animation starts, with a logged warning.
- LCH interpolation from a near-grey, such as `.secondaryLabel`, swept through
  unrelated hues. Hue is now weighted by chroma, so it heads straight for the
  other colour's hue; colours with chroma of 20 or more are unaffected.
- Between Display P3 colours, the frames of an LCH animation were clipped to
  sRGB, so they lost saturation and the last frame jumped to the target. The
  frames in between are now clipped to the smallest of sRGB and Display P3
  that holds both endpoints, in every interpolation mode; animations between
  sRGB colours are unchanged. The example app has a Display P3 swatch.
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
