// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit)
import Foundation

/// Runs its actions one after another.
@MainActor
final class SequenceAction: Action {

    /// The actions still to come, as descriptions. `Kinieta` builds the
    /// timeline by editing this queue.
    var pending: ActionQueue

    var completion: Block?

    /// While paused the sequence reports `.running` without advancing.
    var isPaused = false

    /// A cancelled sequence finishes on its next update without running any
    /// completion block, whether the engine or a group is driving it.
    var isCancelled = false

    var currentAction: Action?

    init(_ types: [ActionType] = [], completion: Block? = nil) {
        self.pending = ActionQueue(types)
        self.completion = completion
    }

    func update(_ frame: Engine.Frame) -> ActionResult {
        if isCancelled { return .finished(overshoot: 0) }
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
                if pending.isEmpty {
                    completion?()
                    return .finished(overshoot: overshoot)
                }
                // Hand the unused part of the frame to the next action so a
                // boundary never costs a frame. Nothing left: wait for the next one.
                guard overshoot > 0 else { return .running }
                frame = Engine.Frame(frame.timestamp, overshoot)
            }
        }
    }
}
#endif
