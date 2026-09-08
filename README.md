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
- **Swift 6, iOS 17+.** Main-actor isolated, Sendable where it matters, Reduce Motion aware.

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
| `.frame` | `CGRect` | `frame` |
| `.alpha` | `0...1` | `alpha` |
| `.rotation(degrees:)` | degrees | `transform` (replaces any scale) |
| `.background` | `UIColor` | `backgroundColor` |
| `.borderColor` | `UIColor` | `layer.borderColor` |
| `.borderWidth` | `CGFloat` in points | `layer.borderWidth` |
| `.cornerRadius` | `CGFloat` in points | `layer.cornerRadius` |

Position and size are interpolated through `center` and `bounds`, so they stay correct while a rotation is applied.

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

Chained calls run one after another. `wait` inserts a pause; `delay` postpones the previous action; `repeat` appends copies of the whole chain.

```swift
view.animate(.x(250), .y(500), duration: 0.5).easeInOut(.cubic)
    .wait(0.5)
    .animate(.x(300), .y(200), duration: 0.5).easeInOut(.cubic)
    .animate(.x(0), .y(0), duration: 0.5).delay(0.2)
    .repeat(times: 1)
```

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

Handles hold their view weakly. A timeline finishes on its own when its view is deallocated and never keeps it alive.

### Colour

Colours interpolate through the perceptual CIE LCH space by default, with hue taking the shorter arc. Choose per property or change the engine default:

```swift
view.animate(.background(.systemBlue, interpolation: .rgb), duration: 1.0)
Engine.shared.colorInterpolation = .hsb   // .rgb, .hsb or .lch
```

### Reduce Motion

When the user has Reduce Motion on, animations snap to their end state and completion blocks still run. Pauses keep their duration so sequence timing is preserved. Opt out with `Engine.shared.respectsReduceMotion = false`.

## Example app

`Example/KinietaDemo.xcodeproj` is a gallery: every easing preset on its own track, the three colour spaces side by side, and a composed timeline with a grouped completion. Launch it with the `-autoplay` argument to start playing on launch.

## Development

```
xcodebuild -scheme Kinieta -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
xcodebuild -project Example/KinietaDemo.xcodeproj -scheme KinietaDemo -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcrun swift-format lint --recursive Sources Tests
```

Requires Xcode 26. Documentation is a DocC catalog in `Sources/Kinieta/Kinieta.docc`, including a guide for migrating from 0.5.

## License

MIT. See [LICENSE](LICENSE).
