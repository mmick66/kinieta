// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit)
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
            return .finished(overshoot: frame.duration)
        }

        var stillRunning: [Action] = []
        var overshoot = frame.duration
        for action in actions {
            switch action.update(frame) {
            case .running: stillRunning.append(action)
            case .finished(let unused): overshoot = min(overshoot, unused)
            }
        }
        running = stillRunning

        if stillRunning.isEmpty {
            complete?()
            // The group ends when its last child ends, so the smallest remainder wins.
            return .finished(overshoot: overshoot)
        }
        return .running
    }
}
#endif
