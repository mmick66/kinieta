// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit)
import Foundation

/// Runs its actions one after another.
@MainActor
final class SequenceAction: Action {

    /// The actions still to come, as descriptions. `Kinieta` keeps this in
    /// step with the unstarted end of its timeline.
    var pending: ActionQueue

    var completion: Block?

    /// While paused the sequence reports `.running` without advancing.
    var isPaused = false

    /// A cancelled sequence finishes on its next update without running any
    /// completion block, whether the engine or a group is driving it.
    var isCancelled = false

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

    init(_ types: [ActionType] = [], completion: Block? = nil) {
        self.pending = ActionQueue(types)
        self.completion = completion
    }

    func update(_ frame: Engine.Frame) -> ActionResult {
        if isCancelled || cancelIfViewIsGone() { return .finished(overshoot: 0) }
        if isPaused { return .running }

        var frame = frame
        while true {
            if currentAction == nil { currentAction = pending.popFirstAction() }
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
                // this sequence; honour that before anything else runs.
                if isCancelled { return .finished(overshoot: 0) }
                if isPaused { return .running }
                if pending.isEmpty {
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
