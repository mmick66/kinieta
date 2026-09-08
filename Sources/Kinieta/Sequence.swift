// Kinieta — MIT License. See LICENSE.

import Foundation

/// Runs its actions one after another.
@MainActor
final class Sequence: ActionQueue, Action {

    var complete: Block?

    /// While paused the sequence reports `.running` without advancing.
    var isPaused = false

    var currentAction: Action?

    init(_ types: [ActionType] = [], complete: Block? = nil) {
        self.complete = complete
        super.init(types)
    }

    func update(_ frame: Engine.Frame) -> ActionResult {
        if isPaused { return .running }

        if let current = currentAction {
            switch current.update(frame) {
            case .running:
                return .running
            case .finished:
                currentAction = nil
                if !isEmpty { return .running }
                complete?()
                return .finished
            }
        }

        if let next = popFirstAction() {
            currentAction = next
            return update(frame)
        }

        complete?()
        return .finished
    }
}
