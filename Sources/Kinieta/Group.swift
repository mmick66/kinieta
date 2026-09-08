// Kinieta — MIT License. See LICENSE.

import Foundation

/// Runs its actions at the same time and finishes when the last one does.
@MainActor
final class Group: ActionQueue, Action {

    let complete: Block?
    private var running: [Action]?

    init(_ types: [ActionType] = [], complete: Block? = nil) {
        self.complete = complete
        super.init(types)
    }

    /// Groups actions that are already live, such as the sequences of other handles.
    init(_ actions: [Action], complete: Block? = nil) {
        self.complete = complete
        self.running = actions
        super.init()
    }

    func update(_ frame: Engine.Frame) -> ActionResult {
        if running == nil, !isEmpty {
            running = popAllActions()
        }
        guard let actions = running else {
            complete?()
            return .finished
        }

        let stillRunning = actions.filter { $0.update(frame) == .running }
        running = stillRunning

        if stillRunning.isEmpty {
            complete?()
            return .finished
        }
        return .running
    }
}
