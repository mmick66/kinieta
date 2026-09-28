// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit)
import Foundation

/// An ordered list of pending action descriptions, owned by a `SequenceAction`.
/// Descriptions become live actions only when they are popped.
@MainActor
struct ActionQueue {

    private(set) var types: [ActionType]

    init(_ types: [ActionType] = []) {
        self.types = types
    }

    var isEmpty: Bool { types.isEmpty }

    var count: Int { types.count }

    mutating func add(_ type: ActionType) {
        types.append(type)
    }

    mutating func popLast() -> ActionType? {
        types.popLast()
    }

    mutating func popFirstAction(control: TimelineControl) -> Action? {
        guard !types.isEmpty else { return nil }
        return types.removeFirst().makeAction(control: control)
    }

    /// Removes and returns every trailing action up to, but not including,
    /// the last group. Used by `parallel()` and `then()`.
    mutating func popAllUngrouped() -> [ActionType] {
        var actions: [ActionType] = []
        while let last = popLast() {
            if case .group = last {
                add(last)
                break
            }
            actions.insert(last, at: 0)
        }
        return actions
    }
}
#endif
