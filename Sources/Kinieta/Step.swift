// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit)
import UIKit
#elseif os(macOS)
import AppKit
#endif

#if canImport(UIKit) || os(macOS)
import os

/// One step of a timeline, as a value: an animation, a wait, a call, or
/// several steps run one after another or together.
///
/// Build a whole timeline as one step and run it on a view with `run`:
///
/// ```swift
/// card.run {
///     Step.animate(.alpha(1), duration: 0.3)
///     Step.parallel {
///         Step.animate(.y(40), duration: 0.5, easing: .out(.back))
///         Step.animate(.background(.systemTeal), duration: 0.5)
///     }
///     Step.wait(1)
///     Step.animate(.alpha(0), duration: 0.3)
///         .onComplete { card.removeFromSuperview() }
/// }
/// ```
///
/// Write `Step.` on every line inside a builder. A line that starts with a
/// dot continues the expression on the line before it, so `.animate(…)` on
/// its own line would be read as a call on the previous step rather than as
/// a new one. That is also what lets a modifier such as
/// ``onComplete(_:)`` sit on its own line under the step it modifies.
///
/// A step's animations have no view until it runs: `run` binds them to the
/// view it is called on, so one step value can run on many views, each
/// animating independently.
///
/// Each modifier returns a new step and leaves the original as it was.
public struct Step {

    /// The description of what the step does, as the chain builds it.
    let action: ActionType

    init(_ action: ActionType) {
        self.action = action
    }
}

@MainActor
extension Step {

    private static let logger = Logger(subsystem: "Kinieta", category: "Timeline")

    // MARK: Making steps

    /// A step that animates `properties` to their values over `duration`
    /// seconds, after `delay` seconds, shaped by `easing`. A zero duration
    /// sets them on the frame the step starts.
    ///
    /// A negative, NaN or infinite duration is treated as zero and logs a
    /// warning. `delay` accepts the same times as ``wait(_:)``.
    public static func animate(
        _ properties: Property..., duration: TimeInterval = 0, delay: TimeInterval = 0, easing: Easing = .linear
    ) -> Step {
        animate(properties, duration: duration, delay: delay, easing: easing)
    }

    /// A step that animates `properties` to their values over `duration`
    /// seconds, after `delay` seconds, shaped by `easing`. Same as
    /// ``animate(_:duration:delay:easing:)-(Property...,_,_,_)`` with an array.
    public static func animate(
        _ properties: [Property], duration: TimeInterval = 0, delay: TimeInterval = 0, easing: Easing = .linear
    ) -> Step {
        let duration = Kinieta.sanitized(duration, in: "Step.animate(duration:)", allowsInfinity: false)
        let delay = Kinieta.sanitized(delay, in: "Step.animate(delay:)", allowsInfinity: true)
        let animation = Step(.animation(AnimationSpec(nil, properties, duration: duration, easing: easing.bezier)))
        return delay > 0 ? animation.delayed(by: delay) : animation
    }

    /// A step that waits for `duration` seconds.
    ///
    /// A negative or NaN duration is treated as zero and logs a warning.
    /// `.infinity` waits until the timeline is cancelled.
    public static func wait(_ duration: TimeInterval) -> Step {
        Step(.pause(Kinieta.sanitized(duration, in: "Step.wait(_:)", allowsInfinity: true)))
    }

    /// A step that calls `block` and takes no time.
    ///
    /// The block runs on the frame the step before it ends. It does not run
    /// once the timeline has been cancelled or its view deallocated.
    public static func call(_ block: @escaping Kinieta.Completion) -> Step {
        Step(.call(block))
    }

    /// A step that runs `steps` one after another and ends when the last does.
    ///
    /// Each step starts on the frame the one before it ends, with the part of
    /// that frame it did not use. With no steps it ends at once.
    public static func sequence(@StepBuilder _ steps: () -> [Step]) -> Step {
        Step(.sequence(steps().map(\.action)))
    }

    /// A step that runs `steps` together and ends when the last of them does.
    ///
    /// A `for` loop in the builder gives one step per element, for example to
    /// stagger several views:
    ///
    /// ```swift
    /// Step.parallel {
    ///     for (index, cell) in cells.enumerated() {
    ///         Step.sequence { … }.delay(Double(index) * 0.05)
    ///     }
    /// }
    /// ```
    ///
    /// With no steps it ends at once.
    public static func parallel(@StepBuilder _ steps: () -> [Step]) -> Step {
        Step(.group(steps().map(\.action)))
    }

    // MARK: Modifying steps

    /// The step, started after a pause of `duration` seconds.
    ///
    /// Accepts the same times as ``wait(_:)``. Delaying a step twice adds
    /// the two delays.
    public func delay(_ duration: TimeInterval) -> Step {
        delayed(by: Kinieta.sanitized(duration, in: "Step.delay(_:)", allowsInfinity: true))
    }

    /// The step after a pause of `duration` seconds, which is the shape the
    /// chain's `delay(_:)` builds.
    private func delayed(by duration: TimeInterval) -> Step {
        Step(.sequence([.pause(duration), action]))
    }

    /// The step, followed by a call to `block` when it ends.
    ///
    /// The block runs on the frame the step ends, and not at all once the
    /// timeline has been cancelled or its view deallocated. Calling this
    /// twice runs both blocks, in order.
    public func onComplete(_ block: @escaping Kinieta.Completion) -> Step {
        // Always a new call, never `ActionType.withCompletion`: the step may be
        // a `sequence` that ends with a call of its own, and that would replace it.
        Step(.sequence([action, .call(block)]))
    }

    /// The step, played once and then `times` more times, as the chain's
    /// `repeat(times:)` does.
    ///
    /// The step is held once with a count rather than copied, so `times` has
    /// no limit. Each cycle starts on the frame the one before it ends, with
    /// the part of that frame it did not use, and runs any completion
    /// blocks inside it again. A negative count is treated as zero and logs a
    /// warning. To play the step until the timeline is cancelled, use
    /// ``repeatForever()``.
    public func `repeat`(times: Int) -> Step {
        if times < 0 {
            Step.logger.warning("Step.repeat(times:) was given \(times, privacy: .public) times; using 0")
        }
        guard times > 0 else { return self }
        // A count of `Int.max` cycles cannot overflow: `times` is at most `Int.max - 1` here.
        return Step(.repeating(times == .max ? .max : times + 1, [action]))
    }

    /// The step, played over and over until the timeline is cancelled.
    ///
    /// It never ends, so nothing after it in a sequence runs, a group that
    /// holds it never ends either, and ``Kinieta/finished()`` returns only
    /// once the timeline is cancelled or its view is deallocated. A cycle
    /// that takes no time plays once per frame.
    public func repeatForever() -> Step {
        Step(.loop([action]))
    }
}

/// Builds the steps of ``Step/sequence(_:)``, ``Step/parallel(_:)`` and
/// `run`, one per line, from `if`, `if`-`else`, `switch` and `for` as well
/// as single steps.
@resultBuilder
public enum StepBuilder {

    /// One step, written on its own line.
    public static func buildExpression(_ step: Step) -> [Step] {
        [step]
    }

    /// The steps of every line, in order.
    public static func buildBlock(_ components: [Step]...) -> [Step] {
        components.flatMap { $0 }
    }

    /// The steps of an `if` without an `else`, or none when its condition is false.
    public static func buildOptional(_ component: [Step]?) -> [Step] {
        component ?? []
    }

    /// The steps of the first branch of an `if`-`else` or `switch`.
    public static func buildEither(first component: [Step]) -> [Step] {
        component
    }

    /// The steps of the second branch of an `if`-`else` or `switch`.
    public static func buildEither(second component: [Step]) -> [Step] {
        component
    }

    /// The steps of every pass of a `for` loop, in order.
    public static func buildArray(_ components: [[Step]]) -> [Step] {
        components.flatMap { $0 }
    }
}
#endif
