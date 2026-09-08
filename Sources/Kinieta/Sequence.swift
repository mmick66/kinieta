// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit)
import Foundation

/// Runs its actions one after another.
@MainActor
final class Sequence: ActionQueue, Action {

    var complete: Block?

    /// While paused the sequence reports `.running` without advancing.
    var isPaused = false

    /// A cancelled sequence finishes on its next update without running any
    /// completion block, whether the engine or a group is driving it.
    var isCancelled = false

    var currentAction: Action?

    init(_ types: [ActionType] = [], complete: Block? = nil) {
        self.complete = complete
        super.init(types)
    }

    func update(_ frame: Engine.Frame) -> ActionResult {
        if isCancelled { return .finished(overshoot: 0) }
        if isPaused { return .running }

        var frame = frame
        while true {
            if currentAction == nil { currentAction = popFirstAction() }
            guard let current = currentAction else {
                complete?()
                return .finished(overshoot: frame.duration)
            }
            switch current.update(frame) {
            case .running:
                return .running
            case .finished(let overshoot):
                currentAction = nil
                if isEmpty {
                    complete?()
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
