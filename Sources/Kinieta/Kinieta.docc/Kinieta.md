# ``Kinieta``

A timeline animation engine for UIKit with a typed, chainable API.

@Metadata {
    @Available(iOS, introduced: "17.0")
    @Available("Mac Catalyst", introduced: "17.0")
    @Available(tvOS, introduced: "17.0")
    @Available(visionOS, introduced: "1.0")
    @Available(macOS, introduced: "14.0")
}

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

### Platforms

Kinieta animates `UIView` on iOS, tvOS and Mac Catalyst 17 and later, and on
visionOS 1 and later. On native macOS 14 and later, support for `NSView` is
experimental: the same timeline API and the same properties, with geometry in
the superview's coordinates, from the bottom left unless the superview is
flipped. `.rotation` sets `frameRotation` about the view's centre, and the
layer properties, such as ``Property/background(_:interpolation:)`` and
``Property/cornerRadius(_:)``, give a view without a layer one. Where a
signature names the view or colour type, such as
``Property/custom(_:to:interpolation:isMotion:)-(ReferenceWritableKeyPath<Root,Value>,_,_,_)``,
this documentation shows the platform it was built for: AppKit has the same
API with `NSView` and `NSColor` where UIKit has `UIView` and `UIColor`.

## Topics

### Starting a timeline

Call `animate(_:duration:delay:easing:)` or `wait(_:)` on any `UIView`; both
return a ``Kinieta`` handle. An animation's `delay` postpones its start and its
``Easing`` shapes it; they default to none and ``Easing/linear``.

```swift
view.animate(.x(250), duration: 0.5, delay: 0.2, easing: .inOut(.cubic))
```

Durations and delays are in seconds. A negative or NaN one is treated as zero
and logs a warning. Only waits and delays accept `.infinity`, which holds the
timeline until it is cancelled; an infinite animation duration is treated as
zero.

- ``Property``

### Composing timelines from steps

A ``Step`` is a timeline, or a part of one, written as a single value with a
result builder. One step can run on many views, and one timeline from
``Kinieta/run(_:)-(()->[Step])`` can animate several views.

- <doc:ComposingTimelinesFromSteps>
- ``Step``
- ``StepBuilder``

### Animating anything else

``Property/custom(_:to:interpolation:isMotion:)-(ReferenceWritableKeyPath<Root,Value>,_,_,_)``
animates any writable key path of a view to an ``Interpolatable`` value, and
``Property/constant(of:to:)`` animates an Auto Layout constraint's constant,
laying out its views every frame so a constrained view does not snap back.

- ``Interpolatable``
- ``CustomProperty``

### Shaping it

An ``Easing`` maps time to progress through a ``Bezier`` curve, which takes its
control points in CSS `cubic-bezier()` order. ``Bezier/progress(at:)`` gives a
curve's eased progress at a time fraction.

- ``Kinieta``
- ``Easing``
- ``Bezier``
- ``ColorInterpolation``

### Looping

``Kinieta/repeat(times:file:line:)`` appends copies of the chain so far, and
``Kinieta/repeatForever(file:line:)`` replays it until the timeline is
cancelled, as a spinner or a pulsing badge needs. A looping timeline never
finishes, so ``Kinieta/finished()`` returns only once it is cancelled, and a
chain call made after the loop does nothing.

- ``Kinieta/repeatForever(file:line:)``
- ``Kinieta/repeat(times:file:line:)``

### Controlling it

A newer animation of a property takes it over from an older one still running
on the same view, starting from the value on screen. The older animation stops
writing that property, keeps animating the rest and runs its completion block
when its duration ends. `.frame` counts as `.x`, `.y`, `.width` and `.height`,
and a key path to the view's `transform` counts as `.rotation`.

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
