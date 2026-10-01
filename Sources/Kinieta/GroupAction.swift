// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit) || os(macOS)
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

    /// The timeline this group runs in. A group of timelines is handed the
    /// group handle's when it is made live; see `ActionType.makeAction(control:)`.
    var control: TimelineControl
    private var phase: Phase
    /// Actions that joined since the last update, or during it.
    private var joining: [Action] = []
    private var hasEnded = false

    init(pending types: [ActionType], control: TimelineControl = TimelineControl()) {
        self.phase = .pending(types)
        self.control = control
    }

    /// Groups actions that are already live, such as the timelines of other handles.
    init(running actions: [Action], control: TimelineControl = TimelineControl()) {
        self.phase = .running(actions)
        self.control = control
    }

    /// Idle once started and every member is idle. A group with no members
    /// is not: it finishes on its next update.
    var isIdle: Bool {
        guard case .running(let live) = phase else { return false }
        let members = live + joining
        return !members.isEmpty && members.allSatisfy(\.isIdle)
    }

    /// Abandoned once every member is: a member whose handle is still around
    /// can be resumed or cancelled, and the group moves on with it.
    var isAbandoned: Bool {
        guard case .running(let live) = phase else { return false }
        let members = live + joining
        return !members.isEmpty && members.allSatisfy(\.isAbandoned)
    }

    /// Adds an action that is already live, such as a grouped timeline that
    /// was extended after it finished. Returns `false` once the group has ended.
    func adopt(_ action: Action) -> Bool {
        guard !hasEnded else { return false }
        joining.append(action)
        return true
    }

    /// Ends a started group without running it again and returns the members
    /// it was still running, for another driver to take over.
    func releaseMembers() -> [Action] {
        guard case .running(let live) = phase else { return [] }
        let members = live + joining
        phase = .running([])
        joining = []
        hasEnded = true
        return members
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
            // A member's completion block may have halted the timeline: leave
            // the members after it as they are.
            if case .stop = control.checkpoint(hasMoreToRun: true) {
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

        // Nothing else runs this frame, so a lost view waits for the next one.
        // Paused after the last member finished: complete on resume, as a sequence does.
        if case .stop(let result) = control.checkpoint(hasMoreToRun: false) {
            if result.isFinished { hasEnded = true }
            return result
        }
        if stillRunning.isEmpty {
            hasEnded = true
            // The group ends when its last child ends, so the smallest remainder wins.
            return .finished(overshoot: overshoot)
        }
        return .running
    }
}
#endif
