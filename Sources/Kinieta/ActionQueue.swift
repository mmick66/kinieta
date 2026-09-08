// Kinieta — MIT License. See LICENSE.

import Foundation

/// An ordered list of pending action descriptions, shared by `Sequence` and
/// `Group`. Descriptions become live actions only when they are popped.
@MainActor
class ActionQueue {

    private(set) var types: [ActionType]

    init(_ types: [ActionType] = []) {
        self.types = types
    }

    var isEmpty: Bool { types.isEmpty }

    func add(_ type: ActionType) {
        types.append(type)
    }

    func popLast() -> ActionType? {
        types.popLast()
    }

    func popFirstAction() -> Action? {
        guard !types.isEmpty else { return nil }
        return types.removeFirst().makeAction()
    }

    func popAllActions() -> [Action] {
        var actions: [Action] = []
        while let action = popFirstAction() { actions.append(action) }
        return actions
    }

    /// Removes and returns every trailing action up to, but not including,
    /// the last group. Used by `parallel()` and `then`.
    func popAllUngrouped() -> [ActionType] {
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
