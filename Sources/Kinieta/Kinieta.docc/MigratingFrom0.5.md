# Migrating from 0.5

The 1.0 API is typed and chainable; the string-dictionary API is gone.

## Overview

Kinieta 0.5 described animations with dictionaries of `Any`. 1.0 replaces them
with the ``Property`` enum, renames the chain to follow the Swift API Design
Guidelines, and returns a handle you can control.

| 0.5 | 1.0 |
| --- | --- |
| `view.move(to: ["x": 250, "y": 500], during: 0.5)` | `view.animate(.x(250), .y(500), duration: 0.5)` |
| `["w": 10]`, `["h": 10]` | `.width(10)`, `.height(10)` |
| `["a": 0]` | `.alpha(0)` |
| `["r": 30]` | `.rotation(degrees: 30)` |
| `["bg": color]`, `["brc": color]` | `.background(color)`, `.borderColor(color)` |
| `["brw": 2]`, `["crd": 8]` | `.borderWidth(2)`, `.cornerRadius(8)` |
| `.easeInOut(.Back)` | `.easeInOut(.back)` or `.easing(.inOut(.back))` |
| `.easeInOut(.Custom(bezier))` | `.easing(.custom(bezier))` |
| `.wait(for: 1)` | `.wait(1)` |
| `.delay(for: 1)` | `.delay(1)` |
| `.again(times: 2)` | `.repeat(times: 2)` |
| `.complete { }` | `.onComplete { }` |
| `Engine.shared.group([a, b]) { }` | `Kinieta.group(a, b) { }` |
| `Defaults.ColorInterpolation.Method = .RGB_HLC_Assisted` | `Engine.shared.colorInterpolation = .lch` (the default) |

## Behaviour changes

- Colours interpolate through LCH by default. Pass
  `.background(color, interpolation: .rgb)` for the old straight-line result.
- Easing curves are evaluated at time `x`, as CSS does. 0.5 evaluated them at
  the curve parameter, which distorted every preset.
- Time advances by the real elapsed interval, so dropped frames catch up.
- Views are held weakly. A timeline finishes on its own when its view is
  deallocated and never keeps it alive.
- Zero-duration animations and pauses run their completion blocks.
- Animations snap to their end state when Reduce Motion is on. Set
  `Engine.shared.respectsReduceMotion = false` to opt out.
- `then` keeps the order of the actions it seals.

## Distribution

Add the package with Swift Package Manager:

```
https://github.com/mmick66/kinieta
```

1.0.0 is also the final CocoaPods release.
