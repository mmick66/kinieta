// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit) || os(macOS)
import Foundation

/// The action descriptions of a `SequenceAction`, in order. Descriptions
/// become live actions only when they are popped.
///
/// Popping moves a cursor instead of removing the step, so every operation is
/// O(1) apart from `popAllUngrouped`, which is linear in what it returns. The
/// popped steps stay in `steps`, which is how a timeline remembers what it has
/// already run for `repeat`.
@MainActor
struct ActionQueue {

    /// Every step: first the ones already popped, then the ones still to come.
    private(set) var steps: [ActionType]
    /// The index in `steps` of the next step to pop.
    private var next = 0

    init(_ steps: [ActionType] = []) {
        self.steps = steps
    }

    /// `true` when no step is left to pop.
    var isEmpty: Bool { next == steps.count }

    /// The number of steps left to pop.
    var count: Int { steps.count - next }

    mutating func add(_ type: ActionType) {
        steps.append(type)
    }

    /// Removes and returns the last step, unless it has already been popped.
    mutating func popLast() -> ActionType? {
        isEmpty ? nil : steps.removeLast()
    }

    mutating func popFirstAction(control: TimelineControl) -> Action? {
        guard !isEmpty else { return nil }
        defer { next += 1 }
        return steps[next].makeAction(control: control)
    }

    /// Removes and returns every trailing step not yet popped, up to but not
    /// including the last group. Used by `parallel()` and `then()`.
    mutating func popAllUngrouped() -> [ActionType] {
        var start = steps.count
        while start > next {
            if case .group = steps[start - 1] { break }
            start -= 1
        }
        let actions = Array(steps[start...])
        steps.removeSubrange(start...)
        return actions
    }
}
#endif
