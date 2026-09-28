# ``Kinieta``

A timeline animation engine for UIKit with a typed, chainable API.

## Overview

Kinieta animates `UIView` properties on a display link and composes those
animations into timelines: one after another, side by side, grouped across
several views with a single completion.

```swift
square.animate(.x(374), .background(.systemPink), duration: 1.0)
      .easeInOut(.back)
      .wait(1.0)
      .animate(.x(74), duration: 0.5)
      .onComplete { print("back home") }
```

Every timeline is a ``Kinieta`` handle. Keep it to ``Kinieta/cancel()``,
``Kinieta/pause()``, ``Kinieta/resume()`` or `await` ``Kinieta/finished()``.
A handle can be extended at any time: actions added to a finished timeline
start it again, while a cancelled timeline stays cancelled.

Colours interpolate through the perceptual LCH space by default, so a
transition from pink to cyan never passes through grey. Easing curves are cubic
Béziers with the same semantics as CSS and cubic-bezier.com.

## Topics

### Starting a timeline

Call `animate(_:duration:)` or `wait(_:)` on any `UIView`; both return a ``Kinieta`` handle.

Durations are in seconds. A negative or NaN duration is treated as zero and
logs a warning. Only `wait(_:)` and `delay(_:)` accept `.infinity`, which holds
the timeline until it is cancelled; an infinite animation duration is treated
as zero.

- ``Property``

### Shaping it

- ``Kinieta``
- ``Easing``
- ``Bezier``
- ``ColorInterpolation``

### Engine settings

- ``Engine``
- ``Engine/preferredFrameRateRange``
- ``Engine/defaultFrameRateRange``

### Reduce Motion

When the user has Reduce Motion on, position, size and rotation snap to their
end state, while opacity, colours, border width and corner radius still animate
over the full duration, so fades and colour changes keep giving feedback.
Completion blocks run and pauses keep their duration, so a timeline's timing is
unchanged.

- ``Engine/reduceMotionBehavior``
- ``ReduceMotionBehavior``
- ``Engine/respectsReduceMotion``

### Migrating

- <doc:MigratingFrom0.5>
- <doc:DeprecatedColorHelpers>
