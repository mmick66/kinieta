// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit) || os(macOS)
import Foundation

/// The timelines a handle from `Kinieta.group` runs, and the bookkeeping
/// that keeps each of them in step with it.
///
/// Every member has this group's handle as its owner until it leaves: a
/// member belongs to at most one group. Cancelling, pausing and resuming the
/// group handle does the same to every member. A member extended after it
/// finished rejoins the group while the group still runs, and leaves it
/// otherwise. A group handle released while paused frees the members it was
/// still running, for the engine to drive.
@MainActor
final class GroupMembership {

    /// The handles of the timelines in the group, including those that have
    /// finished, until they leave it.
    private var members: [Kinieta]
    /// The action running the members' timelines; `nil` once the group has ended.
    private var action: GroupAction?

    init(_ members: [Kinieta], runningIn action: GroupAction) {
        self.members = members
        self.action = action
    }

    /// What the members' timelines hold now, as steps that can run again.
    /// `repeat` on the group handle replays these.
    var replay: [ActionType] {
        members.map { .sequence($0.timeline) }
    }

    /// Takes back `member`, extended after it finished. Returns `false` once the
    /// group has ended: `member` then leaves the group, for the engine to drive.
    func adopt(_ member: Kinieta) -> Bool {
        if action?.adopt(member.root) == true { return true }
        members.removeAll { $0 === member }
        return false
    }

    /// Ends the group with its handle's timeline. A member that is extended
    /// later leaves the group.
    func end() {
        action = nil
    }

    /// Hands the members the group was still running to the engine, after its
    /// handle was released while paused. Each keeps its state.
    func releaseMembers() {
        for case let timeline as TimelineAction in action?.releaseMembers() ?? [] {
            timeline.handle?.leaveReleasedGroup()
        }
    }

    /// Cancels every member, adding their roots to `cancelled`.
    func cancel(collecting cancelled: inout [Action]) {
        for member in members { member.cancel(collecting: &cancelled) }
    }

    /// Pauses every member.
    func pause() {
        for member in members { member.pause() }
    }

    /// Resumes every member.
    func resume() {
        for member in members { member.resume() }
    }
}
#endif
