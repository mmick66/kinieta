<p align="center">
  <img src="Assets/Kinieta_Logo.png" alt="Kinieta">
</p>

# Kinieta

A timeline animation engine for UIKit with a typed, chainable API.

- **Timelines.** Animations run one after another, side by side, or grouped across views with a single completion.
- **Typed properties.** `.x(250)`, `.background(.systemPink)`, `.rotation(degrees: 30)`. Wrong types are compile errors.
- **Real easing.** Cubic Bézier curves with the same semantics as CSS and cubic-bezier.com, plus presets from sine to back.
- **Perceptual colour.** Colours interpolate through LCH by default, so pink to cyan never passes through grey.
- **Handles.** Every timeline can be cancelled, paused, resumed or awaited.
- **Swift 6, iOS, tvOS and Mac Catalyst 17+.** Main-actor isolated, Sendable where it matters, Reduce Motion aware.

```swift
square.animate(.x(374), .background(.systemPink), duration: 1.0)
      .easeInOut(.back)
      .wait(1.0)
      .animate(.x(74), duration: 0.5)
      .onComplete { print("back home") }
```

<p align="center">
  <img src="Assets/demo.gif" alt="The example app playing every easing preset" width="360">
</p>

## Installation

### Swift Package Manager

In Xcode choose File, then Add Package Dependencies, and enter:

```
https://github.com/mmick66/kinieta
```

Or in `Package.swift`:

```swift
.package(url: "https://github.com/mmick66/kinieta", from: "1.0.0")
```

### CocoaPods

1.0.0 is the final CocoaPods release. Prefer Swift Package Manager.

```ruby
pod 'Kinieta', '~> 1.0'
```

## Usage

### Animating

`animate` sets properties over a duration. Omit the duration to set them on the next frame.

```swift
view.animate(.x(250), .y(500))                      // next frame
view.animate(.x(250), .y(500), duration: 0.5)       // half a second
view.animate(.frame(target), .alpha(0), duration: 0.3)
```

| Property | Value | Animates |
| --- | --- | --- |
| `.x`, `.y` | `CGFloat` in points | position of the top-left corner |
| `.width`, `.height` | `CGFloat` in points | size, keeping the top-left corner fixed |
| `.frame` | `CGRect` | position and size together, as the frame before any rotation |
| `.alpha` | `0...1` | `alpha` |
| `.rotation(degrees:)` | degrees | `transform`, keeping its scale and translation |
| `.background` | `UIColor` | `backgroundColor` |
| `.borderColor` | `UIColor` | `layer.borderColor` |
| `.borderWidth` | `CGFloat` in points | `layer.borderWidth` |
| `.cornerRadius` | `CGFloat` in points | `layer.cornerRadius` |

Position and size, `.frame` included, are interpolated through `center` and `bounds`, so they stay correct while a rotation is applied: on a rotated view `.frame` sets the rect it would occupy unrotated, not UIKit's bounding-box `frame`. Rotation is not wrapped: after `.rotation(degrees: 720)`, animating to `810` turns a quarter, and going from `270` to `360` turns 90°, not 450°. Sizes, border width and corner radius never go below zero, even with an overshooting curve.

**Auto Layout.** Kinieta sets geometry directly. A view positioned by constraints snaps back on the next layout pass, which device rotation, size class changes and the keyboard all trigger. Animate unconstrained views, or animate constraint constants yourself.

### Easing

Apply an easing to the previous animation. The default is linear.

```swift
view.animate(.x(250), duration: 0.5).easeIn()             // quad
view.animate(.x(250), duration: 0.5).easeOut(.cubic)
view.animate(.x(250), duration: 0.5).easeInOut(.back)
view.animate(.x(250), duration: 0.5).easing(.inOut(.expo))
```

Curves: `.sine`, `.quad`, `.cubic`, `.quart`, `.quint`, `.expo`, `.back`, and `.custom(Bezier)`. A `Bezier` takes the two inner control points in the order [cubic-bezier.com](https://cubic-bezier.com/#.16,.73,.89,.24) lists them:

```swift
let snap = Bezier(0.16, 0.73, 0.89, 0.24)
view.animate(.x(250), duration: 1.0).easing(.custom(snap))
```

Curves are baked into a lookup table once and solved at time `x`, exactly like CSS `cubic-bezier()`. Curves such as `back` overshoot on purpose.

### Sequencing

Chained calls run one after another. `wait` inserts a pause; `delay` postpones the previous action; `repeat` appends copies of the whole chain, including the actions already running or done.

```swift
view.animate(.x(250), .y(500), duration: 0.5).easeInOut(.cubic)
    .wait(0.5)
    .animate(.x(300), .y(200), duration: 0.5).easeInOut(.cubic)
    .animate(.x(0), .y(0), duration: 0.5).delay(0.2)
    .repeat(times: 1)
```

Durations are in seconds. A negative or NaN duration is treated as zero and logs a warning, so it never skips ahead or stalls the timeline. `wait(.infinity)` and `delay(.infinity)` hold the timeline until you cancel it; an infinite `animate` duration is treated as zero.

### Parallel actions

`parallel()` gathers everything added since the last `then` or `parallel()` and runs it together.

```swift
view.animate(.x(200), duration: 1.0).easeInOut(.cubic)
    .animate(.alpha(0), duration: 0.2).delay(0.8).easeOut()
    .parallel()
    .onComplete { print("moved and faded") }
```

Use `then` to seal a step before starting a parallel block:

```swift
view.animate(.x(300), duration: 1.0)      // first, on its own
    .then
    .animate(.x(200), duration: 1.0)      // then these two
    .animate(.alpha(0), duration: 0.2)    // together
    .parallel()
```

### Grouping views

`Kinieta.group` runs several timelines together and calls its completion once, when the last one finishes. It returns a handle for the whole group.

```swift
let slide = card.animate(.x(374), duration: 1.0).easeInOut(.cubic)
let spin  = badge.animate(.rotation(degrees: 360), .alpha(0), duration: 1.2)

Kinieta.group(slide, spin) { print("both finished") }
```

The group is the first step of the handle's own timeline, so the handle chains like any other: `delay` postpones the whole group, `wait` and `onComplete` follow it, and `repeat` replays it.

```swift
Kinieta.group(slide, spin)
    .delay(0.5)
    .onComplete { print("both finished") }
    .wait(1.0)
    .onComplete { print("a second later") }
```

The group handle has no view of its own, so `animate` on it does nothing and logs a warning; animate the grouped timelines instead.

The group handle controls its members: `cancel()` cancels every timeline in the group (their `finished()` calls return), and `pause()` and `resume()` pause and resume them all. A member can still be cancelled or paused on its own, but cannot resume while its group is paused.

A timeline belongs to at most one group. `Kinieta.group` leaves out, with a logged warning, any timeline that is already in a group or has already finished or been cancelled; a timeline listed twice runs once. A member extended after it finished rejoins its group if the group is still running, and otherwise runs on its own.

### Controlling a timeline

Every call returns a `Kinieta` handle.

```swift
let handle = view.animate(.x(250), duration: 2.0)

handle.pause()
handle.resume()
handle.cancel()          // stops where it is; no further completions run
handle.state             // .running, .paused, .finished or .cancelled

await handle.finished()  // suspends until the timeline finishes or is cancelled
```

`cancel()` and `pause()` take effect immediately, even from inside an `onComplete` block: the next action does not start in that frame, and a cancelled timeline stays `.cancelled`.

A handle can be extended at any time, not only while chaining. Actions added to a running timeline play after the ones already there; actions added to a finished timeline start it again on the next frame, and `finished()` waits for them. `Kinieta(for: view)` gives an empty handle to build later. Easing, `delay`, `onComplete`, `then` and `parallel` only reach actions that have not started yet, and a cancelled timeline ignores further calls. A finished timeline forgets its actions, so a later `repeat` copies only what was added since.

Handles hold their view weakly and never keep it alive. When the view is deallocated the timeline is cancelled on the next frame: the rest of it does not run, no further completion blocks are called, and the handle ends `.cancelled`.

### Colour

Colours interpolate through the perceptual CIE LCH space by default, with hue taking the shorter arc. Choose per property or change the engine default. The endpoints are assigned exactly as given, so a dynamic colour such as `.systemBackground` keeps adapting to Dark Mode after the animation, and a Display P3 colour keeps its gamut. Fading to or from `.clear` fades alpha instead of passing through black.

```swift
view.animate(.background(.systemBlue, interpolation: .rgb), duration: 1.0)
Engine.shared.colorInterpolation = .hsb   // .rgb, .hsb or .lch
```

### Reduce Motion

When the user has Reduce Motion on, animations snap to their end state and completion blocks still run. Pauses keep their duration so sequence timing is preserved. Opt out with `Engine.shared.respectsReduceMotion = false`.

### Frame rate

The engine advances by real elapsed time, so it stays on schedule through dropped frames and on 60 Hz and 120 Hz displays alike. It asks for 120 Hz on ProMotion devices; iPhones only honour that when the app's Info.plist sets `CADisableMinimumFrameDurationOnPhone` to `YES`.

The display link only runs while something can move. When every timeline is paused, or waiting on `wait(.infinity)`, the engine stops it, so a paused handle you let go of costs no frames; `resume()`, `cancel()` or a new animation starts it again.

### Platforms

| Platform | Minimum | CI |
| --- | --- | --- |
| iOS | 17 | Tests, including snapshots, on the iPhone 17 Pro / iOS 26.5 simulator |
| Mac Catalyst | 17 | Tests, except the iOS-only snapshot suite |
| tvOS | 17 | Build for the tvOS Simulator |

Kinieta is UIKit only. The sources are guarded with `canImport(UIKit)`, so the package resolves and builds as an empty module on other platforms, such as native macOS, which keeps tooling happy but is not a supported target.

CI checks this on macOS and Linux (Swift 6.3): `swift build` succeeds and `swift test` runs 0 tests, because the tests are guarded the same way. Depending on Kinieta does not pull in swift-snapshot-testing or its swift-syntax dependency; SwiftPM resolves only dependencies of the products you use, and snapshot testing is used by the test target alone.

## Example app

`Example/KinietaDemo.xcodeproj` is a gallery: every easing preset on its own track, the three colour spaces side by side, and a composed timeline with a grouped completion. Launch it with the `-autoplay` argument to start playing on launch.

## Development

Tests run on the pinned simulator runtime: **iPhone 17 Pro, iOS 26.5** (Xcode 26.6). CI uses the same destination, since the snapshot references are only valid for the runtime they were recorded on.

```
xcodebuild -scheme Kinieta -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test
xcodebuild -project Example/KinietaDemo.xcodeproj -scheme KinietaDemo -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' CODE_SIGNING_ALLOWED=NO build
xcrun swift-format lint --strict --recursive Sources Tests Example/KinietaDemo
```

Visual regression is covered by snapshot tests: each property is rendered at five progress points, the colour paths at their midpoint, and dynamic colours in light and dark appearance. Reference images live in `Tests/KinietaTests/__Snapshots__`. After an intentional visual change, re-record them on the pinned iPhone 17 Pro / iOS 26.5 simulator and review the PNGs before committing:

```
TEST_RUNNER_SNAPSHOT_TESTING_RECORD=all xcodebuild -scheme Kinieta -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test
```

`swift test` on a Mac or Linux host builds the tests but runs none of them; use the `xcodebuild` commands above. Requires Xcode 26. Documentation is a DocC catalog in `Sources/Kinieta/Kinieta.docc`, including a guide for migrating from 0.5.

## License

MIT. See [LICENSE](LICENSE).
