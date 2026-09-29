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

### Animating anything else

``Property/custom(_:to:isMotion:)-(ReferenceWritableKeyPath<UIView,Value>,_,_)`` animates any
writable key path of a view to an ``Interpolatable`` value, and
``Property/constant(_:to:)`` animates an Auto Layout constraint's constant,
laying out its views every frame so a constrained view does not snap back.

- ``Interpolatable``
- ``CustomProperty``

### Shaping it

- ``Kinieta``
- ``Easing``
- ``Bezier``
- ``ColorInterpolation``

### Controlling it

A newer animation of a property takes it over from an older one still running
on the same view, starting from the value on screen. The older animation stops
writing that property, keeps animating the rest and runs its completion block
when its duration ends. `.frame` counts as `.x`, `.y`, `.width` and `.height`.

- ``Kinieta/State``
- ``Kinieta/state``

### Engine settings

- ``Engine``
- ``Engine/shared``
- ``Engine/colorInterpolation``
- ``Engine/preferredFrameRateRange``
- ``Engine/defaultFrameRateRange``

### Reduce Motion

When the user has Reduce Motion on, position, size, rotation, constraint
constants, transforms and key paths marked `isMotion` snap to their end state, while
opacity, colours, border width, corner radius and other key paths still animate
over the full duration, so fades and colour changes keep giving feedback.
Completion blocks run and pauses keep their duration, so a timeline's timing is
unchanged.

- ``Engine/reduceMotionBehavior``
- ``ReduceMotionBehavior``
- ``Engine/respectsReduceMotion``

### Name clashes

The module and its main class share the name `Kinieta`, so `Kinieta.Property`
names a member of the class. The class nests each of the library's types under
the same name, so a module with its own `Property`, `Easing` or `Engine` can
still write `Kinieta.Property`, `Kinieta.Easing` and `Kinieta.Engine`.

- ``Kinieta/Completion``
- ``Block``

### Migrating

- <doc:MigratingFrom0.5>
- <doc:DeprecatedColorHelpers>
