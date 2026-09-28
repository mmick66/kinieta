// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit)
import Foundation

/// Runs its actions at the same time and finishes when the last one does.
@MainActor
final class GroupAction: Action {

    private enum Phase {
        /// Not started: the children are still descriptions, made live on the first frame.
        case pending([ActionType])
        /// Started: the children that have not finished yet.
        case running([Action])
    }

    let completion: Block?
    private var phase: Phase

    init(pending types: [ActionType], completion: Block? = nil) {
        self.phase = .pending(types)
        self.completion = completion
    }

    /// Groups actions that are already live, such as the sequences of other handles.
    init(running actions: [Action], completion: Block? = nil) {
        self.phase = .running(actions)
        self.completion = completion
    }

    func update(_ frame: Engine.Frame) -> ActionResult {
        let actions: [Action]
        switch phase {
        case .pending(let types): actions = types.map { $0.makeAction() }
        case .running(let live): actions = live
        }

        var stillRunning: [Action] = []
        var overshoot = frame.duration
        for action in actions {
            switch action.update(frame) {
            case .running: stillRunning.append(action)
            case .finished(let unused): overshoot = min(overshoot, unused)
            }
        }
        phase = .running(stillRunning)

        if stillRunning.isEmpty {
            completion?()
            // The group ends when its last child ends, so the smallest remainder wins.
            return .finished(overshoot: overshoot)
        }
        return .running
    }
}
#endif
