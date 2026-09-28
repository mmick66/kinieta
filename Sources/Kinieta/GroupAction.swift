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

    var completion: Block?
    /// The timeline this group runs in. A group of timelines is handed the
    /// group handle's when it is made live; see `ActionType.makeAction(control:)`.
    var control: TimelineControl
    private var phase: Phase
    /// Actions that joined since the last update, or during it.
    private var joining: [Action] = []
    private var hasEnded = false

    init(pending types: [ActionType], control: TimelineControl = TimelineControl(), completion: Block? = nil) {
        self.phase = .pending(types)
        self.control = control
        self.completion = completion
    }

    /// Groups actions that are already live, such as the sequences of other handles.
    init(running actions: [Action], control: TimelineControl = TimelineControl(), completion: Block? = nil) {
        self.phase = .running(actions)
        self.control = control
        self.completion = completion
    }

    /// Idle once started and every member is idle. A group with no members
    /// is not: it finishes on its next update.
    var isIdle: Bool {
        guard case .running(let live) = phase else { return false }
        let members = live + joining
        return !members.isEmpty && members.allSatisfy(\.isIdle)
    }

    /// Adds an action that is already live, such as a grouped timeline that
    /// was extended after it finished. Returns `false` once the group has ended.
    func adopt(_ action: Action) -> Bool {
        guard !hasEnded else { return false }
        joining.append(action)
        return true
    }

    func update(_ frame: Engine.Frame) -> ActionResult {
        var actions: [Action]
        switch phase {
        case .pending(let types): actions = types.map { $0.makeAction(control: control) }
        case .running(let live): actions = live
        }
        actions += joining
        joining = []

        var stillRunning: [Action] = []
        var overshoot = frame.duration
        for (index, action) in actions.enumerated() {
            // A member's completion block may have cancelled or paused the
            // timeline: leave the members after it as they are.
            if control.isHalted {
                stillRunning += actions[index...]
                break
            }
            switch action.update(frame) {
            case .running: stillRunning.append(action)
            case .finished(let unused): overshoot = min(overshoot, unused)
            }
        }
        // A completion block may have extended a member that finished this frame.
        stillRunning += joining
        joining = []
        phase = .running(stillRunning)

        if control.isCancelled {
            hasEnded = true
            return .finished(overshoot: 0)
        }
        // Paused after the last member finished: complete on resume, as a sequence does.
        if control.isPaused { return .running }

        if stillRunning.isEmpty {
            hasEnded = true
            completion?()
            // The group ends when its last child ends, so the smallest remainder wins.
            return .finished(overshoot: overshoot)
        }
        return .running
    }
}
#endif
