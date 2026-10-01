// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit) || os(macOS)
import Foundation

/// Runs its actions one after another.
@MainActor
final class SequenceAction: Action {

    /// The sequence's steps, as descriptions: the ones already started, then
    /// the ones still to come. A main sequence's queue is its handle's timeline.
    var queue: ActionQueue

    /// Ends a main sequence's handle when its timeline has run. A nested
    /// sequence has none: a block from the chain, such as `onComplete`, is a
    /// call step in its queue.
    var completion: Kinieta.Completion?

    /// Shared with the timeline this sequence belongs to: a main sequence
    /// makes its own and hands it to every sequence and group nested in it.
    let control: TimelineControl

    /// While paused the sequence reports `.running` without advancing.
    var isPaused: Bool {
        get { control.isPaused }
        set { control.isPaused = newValue }
    }

    /// A cancelled sequence finishes on its next update without running any
    /// completion block, whether the engine or a group is driving it.
    var isCancelled: Bool {
        get { control.isCancelled }
        set { control.isCancelled = newValue }
    }

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

    /// The handle whose timeline this is; `nil` for a nested sequence, and
    /// once the handle has been released.
    weak var handle: Kinieta?

    var isIdle: Bool {
        !isCancelled && !control.hasLostView && (isPaused || currentAction?.isIdle == true)
    }

    /// Idle with its handle gone: nothing can resume or cancel it any more.
    /// A nested sequence answers for what it is running; its main sequence
    /// has already checked the handle.
    var isAbandoned: Bool {
        guard isIdle, handle == nil else { return false }
        return isPaused || currentAction?.isAbandoned == true
    }

    init(
        _ types: [ActionType] = [], control: TimelineControl = TimelineControl(), completion: Kinieta.Completion? = nil
    ) {
        self.queue = ActionQueue(types)
        self.control = control
        self.completion = completion
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

    func update(_ frame: Engine.Frame) -> ActionResult {
        if isCancelled || control.cancelIfViewIsGone() { return .finished(overshoot: 0) }
        if isPaused { return .running }

        var frame = frame
        while true {
            if currentAction == nil { currentAction = popNextAction() }
            guard let current = currentAction else {
                completion?()
                return .finished(overshoot: frame.duration)
            }
            switch current.update(frame) {
            case .running:
                return .running
            case .finished(let overshoot):
                currentAction = nil
                // The child's completion block may have cancelled or paused
                // the timeline; honour that before anything else runs.
                if isCancelled { return .finished(overshoot: 0) }
                if isPaused { return .running }
                // With nothing left to run, the timeline ends as finished even
                // if a completion block has released the view.
                if isDone {
                    completion?()
                    return .finished(overshoot: overshoot)
                }
                // A completion block may have released the view: nothing else
                // runs, not even the call of an `onComplete` block.
                if control.cancelIfViewIsGone() { return .finished(overshoot: 0) }
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
