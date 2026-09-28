// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit)
import Foundation

/// Runs its actions one after another.
@MainActor
final class SequenceAction: Action {

    /// The sequence's steps, as descriptions: the ones already started, then
    /// the ones still to come. A main sequence's queue is its handle's timeline.
    var queue: ActionQueue

    var completion: Block?

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

    /// The view of the timeline this sequence runs, if it has one. Once the
    /// view is deallocated the sequence cancels itself before running anything
    /// else and calls `onViewLost`, so its handle can end as cancelled.
    var target: ViewRef?
    var onViewLost: Block?

    var isIdle: Bool {
        !isCancelled && !hasLostView && (isPaused || currentAction?.isIdle == true)
    }

    private var hasLostView: Bool {
        target.map { $0.view == nil } ?? false
    }

    init(_ types: [ActionType] = [], control: TimelineControl = TimelineControl(), completion: Block? = nil) {
        self.queue = ActionQueue(types)
        self.control = control
        self.completion = completion
    }

    func update(_ frame: Engine.Frame) -> ActionResult {
        if isCancelled || cancelIfViewIsGone() { return .finished(overshoot: 0) }
        if isPaused { return .running }

        var frame = frame
        while true {
            if currentAction == nil { currentAction = queue.popFirstAction(control: control) }
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
                if queue.isEmpty {
                    completion?()
                    return .finished(overshoot: overshoot)
                }
                // A completion block may have released the view.
                if cancelIfViewIsGone() { return .finished(overshoot: 0) }
                // Hand the unused part of the frame to the next action so a
                // boundary never costs a frame. Nothing left: wait for the next one.
                guard overshoot > 0 else { return .running }
                frame = Engine.Frame(overshoot)
            }
        }
    }

    private func cancelIfViewIsGone() -> Bool {
        guard hasLostView else { return false }
        isCancelled = true
        onViewLost?()
        return true
    }
}
#endif
