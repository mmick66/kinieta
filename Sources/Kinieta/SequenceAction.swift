// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit) || os(macOS)
import Foundation

/// Runs its actions one after another.
///
/// A handle's timeline is one, run by a `TimelineAction`; the others are
/// nested in it, as members of a group or cycles of a loop.
@MainActor
final class SequenceAction: Action {

    /// The sequence's steps, as descriptions: the ones already started, then
    /// the ones still to come. A handle's sequence's queue is its timeline.
    var queue: ActionQueue

    /// Shared with the timeline this sequence belongs to: its root makes it
    /// and hands it to every sequence and group nested in it.
    let control: TimelineControl

    var currentAction: Action?

    /// The steps still to run of the sequences nested directly in this one,
    /// next step last. A nested sequence, such as the one `delay` or
    /// `onComplete` wraps a step in, runs its steps in line rather than as a
    /// live action of its own, so it adds no layer to every frame they take.
    private var inlined: [ActionType] = []

    /// `true` when no step is left to run.
    private var isDone: Bool { inlined.isEmpty && queue.isEmpty }

    /// `true` when the next step to run starts with a call, which takes no time.
    private var nextIsCall: Bool {
        inlined.last?.startsWithCall ?? queue.nextIsCall
    }

    var isIdle: Bool {
        !control.isCancelled && !control.hasLostView && (control.isPaused || currentAction?.isIdle == true)
    }

    /// Idle with nothing that could wake what it is running. The root checks
    /// whether the handle, which could resume or cancel it, is gone.
    var isAbandoned: Bool {
        isIdle && (control.isPaused || currentAction?.isAbandoned == true)
    }

    init(_ types: [ActionType] = [], control: TimelineControl = TimelineControl()) {
        self.queue = ActionQueue(types)
        self.control = control
    }

    /// Drops every step, started or not, and the blocks they hold.
    func clear() {
        queue = ActionQueue()
        inlined = []
        currentAction = nil
    }

    /// The next step to run as a live action, opening any sequence it meets.
    /// A repeat opens one cycle at a time, behind which it waits with one
    /// cycle fewer, so it runs exactly as that many copies would without
    /// making them.
    private func popNextAction() -> Action? {
        while let step = inlined.popLast() ?? queue.popFirst() {
            switch step {
            case .sequence(let steps):
                inlined.append(contentsOf: steps.reversed())
            case .repeating(let count, let steps):
                guard count > 0 else { continue }
                if count > 1 { inlined.append(.repeating(count - 1, steps)) }
                inlined.append(contentsOf: steps.reversed())
            default:
                return step.makeAction(control: control)
            }
        }
        return nil
    }

    /// Finishes when its last step does, or with no overshoot once the
    /// timeline is cancelled or has lost its view.
    func update(_ frame: Engine.Frame) -> ActionResult {
        if control.isCancelled || control.cancelIfViewIsGone() { return .finished(overshoot: 0) }
        if control.isPaused { return .running }

        var frame = frame
        while true {
            if currentAction == nil { currentAction = popNextAction() }
            guard let current = currentAction else { return .finished(overshoot: frame.duration) }
            switch current.update(frame) {
            case .running:
                return .running
            case .finished(let overshoot):
                currentAction = nil
                if case .stop(let result) = control.checkpoint(hasMoreToRun: !isDone) { return result }
                if isDone { return .finished(overshoot: overshoot) }
                // Hand the unused part of the frame to the next action so a
                // boundary never costs a frame. Nothing left: wait for the
                // next one, unless the next action is a call, which takes no time.
                guard overshoot > 0 || nextIsCall else { return .running }
                frame = Engine.Frame(overshoot)
            }
        }
    }
}
#endif
