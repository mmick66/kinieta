# Composing timelines from steps

Write a whole timeline as one value, and run it on as many views as you like.

## Overview

The chain builds a timeline call by call, and some of its calls edit the one
before: ``Kinieta/easing(_:file:line:)``, ``Kinieta/delay(_:file:line:)`` and
``Kinieta/onComplete(_:file:line:)`` reach back to the previous action, and
``Kinieta/parallel(file:line:)`` gathers everything since the last
``Kinieta/then(file:line:)``. A ``Step`` holds a whole timeline, or any part of
one, as a single value instead, and `run` plays it:

```swift
card.run {
    Step.animate(.alpha(1), duration: 0.3)
    Step.parallel {
        Step.animate(.y(40), duration: 0.5, easing: .out(.back))
        Step.animate(.background(.systemTeal), duration: 0.5)
            .delay(0.1)
    }
    Step.wait(1)
    Step.animate(.alpha(0), duration: 0.3)
        .onComplete { card.removeFromSuperview() }
}
```

### Steps

- ``Step/animate(_:duration:delay:easing:)-(Property...,_,_,_)`` animates
  properties, taking its delay and easing as parameters.
- ``Step/wait(_:)`` waits.
- ``Step/call(_:)`` calls a block and takes no time.
- ``Step/sequence(_:)`` runs its steps one after another.
- ``Step/parallel(_:)`` runs its steps together and ends when the last does.

Every step takes the modifiers ``Step/delay(_:)``, ``Step/onComplete(_:)``,
``Step/repeat(times:)`` and ``Step/repeatForever()``, each of which returns a
new step and leaves the original as it was. There is no easing modifier: easing
is the `easing:` parameter of `Step.animate`, the one step it shapes.

### Running steps

`run(_:)` on a view starts a timeline that runs one step, and `run` with a
trailing closure runs several in sequence. Both return a ``Kinieta`` handle like
`animate`, which you can pause, cancel, group, extend and await.
``Kinieta/run(_:file:line:)`` appends a step to an existing timeline, as
`animate` does: after the actions already there, or restarting a finished one.

### Write Step. on every line

Inside the braces of a builder, write `Step.` at the start of each step. A line
that starts with a dot continues the expression on the line before it, so
`.animate(…)` on a line of its own would be read as a call on the previous step,
not as a new step. The same rule is what lets a modifier such as `.onComplete`
or `.delay` sit on its own line under the step it modifies.

### One step, many views

A step's animations have no view until it runs: `run` gives them the view it is
called on. So one step value can run on several views at once, each animating
on its own timeline, and `if`, `switch` and `for` work inside the braces:

```swift
let rise = Step.animate(.y(0), .alpha(1), duration: 0.4, easing: .out(.cubic))

Kinieta.group(cells.enumerated().map { index, cell in
    cell.run(rise.delay(Double(index) * 0.05))
}) {
    print("all in")
}
```

The timeline is cancelled when its view is deallocated, as with `animate`.

### One timeline, several views

`step` on a view makes a `Step.animate` already bound to that view, and
``Kinieta/run(_:)-(()->[Step])`` runs steps on a timeline of its own, with no
view, so one timeline moves several views with one handle:

```swift
Kinieta.run {
    Step.parallel {
        card.step(.x(374), duration: 1, easing: .inOut(.cubic))
        badge.step(.rotation(degrees: 360), .alpha(0), duration: 1.2)
    }
    Step.call { print("both finished") }
}
```

``Kinieta/run(_:)-(Step)`` runs a single step. The handle pauses, resumes,
cancels, extends and awaits like any other, and its ``Kinieta/view`` is `nil`.
A step made with `view.step` keeps its view wherever it runs: `run` on another
view binds only the animations that have none.

Build a timeline over several views from scratch with `Kinieta.run`; combine
handles that are already running with
``Kinieta/group(_:completion:)-([Kinieta],_)``.

A view deallocated while the timeline runs is skipped rather than cancelling
it: its animations do nothing but still take their time, so the other views
keep animating and later steps run on schedule. A ``Step/call(_:)`` or
``Step/onComplete(_:)`` block after it still runs, so capture views weakly in
it. A plain ``Step/animate(_:duration:delay:easing:)-(Property...,_,_,_)`` has
no view in `Kinieta.run`: in debug builds it logs a warning, and it waits out
its duration, so the steps around it keep their timing.

### Steps and the chain

A step builds the same timeline as the chain and plays it identically, frame
for frame, so the chain stays the shorthand for a short run of actions on one
view. Two modifiers differ:

- ``Step/repeat(times:)`` stores the step once with a count rather than copying
  it, so it has no limit, while the chain's ``Kinieta/repeat(times:file:line:)``
  makes its copies at once and stops at 10,000. Both play the step once and then
  `times` more times.
- ``Step/onComplete(_:)`` always adds a block, while a second chained
  ``Kinieta/onComplete(_:file:line:)`` replaces the first.

## Topics

### Building steps

- ``Step``
- ``StepBuilder``

### Running steps

- ``Kinieta/run(_:)-(()->[Step])``
- ``Kinieta/run(_:)-(Step)``
- ``Kinieta/run(_:file:line:)``
