/*
 * Action.swift
 * Created by Michael Michailidis on 10/09/2017.
 * http://blog.karmadust.com/
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

#if canImport(UIKit)
import UIKit

public typealias Block = () -> Void

/// A weak reference to the view an action targets, so a pending timeline never
/// keeps a view alive. An animation whose view has gone finishes immediately.
struct ViewRef {
    weak var view: UIView?
    init(_ view: UIView?) { self.view = view }
}

/// An animation waiting to run: which view, what to change, and how.
struct AnimationSpec {
    var target: ViewRef
    var properties: [Property]
    var duration: TimeInterval
    /// `nil` means linear.
    var easing: Bezier?
    var completion: Block?

    init(
        _ view: UIView?, _ properties: [Property], duration: TimeInterval,
        easing: Bezier? = nil, completion: Block? = nil
    ) {
        self.target = ViewRef(view)
        self.properties = properties
        self.duration = duration
        self.easing = easing
        self.completion = completion
    }
}

/// The description of an action before it runs. A timeline is a tree of these;
/// they are turned into live `Action` objects when their turn comes.
enum ActionType: CustomStringConvertible {
    case animation(AnimationSpec)
    case pause(TimeInterval, completion: Block? = nil)
    case group([ActionType], completion: Block? = nil)
    case sequence([ActionType], completion: Block? = nil)
    /// The live group behind a `Kinieta.group` handle. Its members are other
    /// handles' sequences, already running, so it cannot be copied.
    case timelines(GroupAction, completion: Block? = nil)

    var description: String {
        switch self {
        case .animation(let spec):
            return "Animation (\(spec.properties.map(\.key.rawValue).joined(separator: " ")))"
        case .pause(let duration, _):
            return "Pause (\(duration))"
        case .group(let types, _):
            return "Group (\(types.count))"
        case .sequence(let types, _):
            return "Sequence (\(types.count))"
        case .timelines:
            return "Timelines"
        }
    }

    /// The same action, calling `completion` when it finishes instead of any previous block.
    func withCompletion(_ completion: @escaping Block) -> ActionType {
        switch self {
        case .animation(var spec):
            spec.completion = completion
            return .animation(spec)
        case .pause(let duration, _):
            return .pause(duration, completion: completion)
        case .group(let types, _):
            return .group(types, completion: completion)
        case .sequence(let types, _):
            return .sequence(types, completion: completion)
        case .timelines(let action, _):
            return .timelines(action, completion: completion)
        }
    }

    /// The same action with every live group of timelines replaced by `replay`,
    /// a copy that can run again. Used by `repeat` on a group handle.
    func replacingTimelines(with replay: [ActionType]) -> ActionType {
        switch self {
        case .animation, .pause:
            return self
        case .group(let types, let completion):
            return .group(types.map { $0.replacingTimelines(with: replay) }, completion: completion)
        case .sequence(let types, let completion):
            return .sequence(types.map { $0.replacingTimelines(with: replay) }, completion: completion)
        case .timelines(_, let completion):
            return .group(replay, completion: completion)
        }
    }

    /// The same action with its last animation eased by `bezier`, looking
    /// inside the sequence `delay` wraps it in; nil if there is no animation to ease.
    func withEasing(_ bezier: Bezier) -> ActionType? {
        switch self {
        case .animation(var spec):
            spec.easing = bezier
            return .animation(spec)
        case .sequence(var types, let completion):
            guard let last = types.popLast(), let eased = last.withEasing(bezier) else { return nil }
            types.append(eased)
            return .sequence(types, completion: completion)
        case .pause, .group, .timelines:
            return nil
        }
    }

    @MainActor
    func makeAction() -> Action {
        switch self {
        case .animation(let spec):
            return PropertyAnimation(spec)
        case .pause(let duration, let completion):
            return PauseAction(duration, completion: completion)
        case .group(let types, let completion):
            return GroupAction(pending: types, completion: completion)
        case .sequence(let types, let completion):
            return SequenceAction(types, completion: completion)
        case .timelines(let action, let completion):
            action.completion = completion
            return action
        }
    }
}

enum ActionResult: Equatable {
    case running
    /// The action ended during this frame; `overshoot` is the part of the
    /// frame it did not use, so the next action can start on time.
    case finished(overshoot: TimeInterval)

    var isFinished: Bool {
        if case .finished = self { return true }
        return false
    }
}

/// Something the engine advances once per frame.
@MainActor
protocol Action: AnyObject {
    func update(_ frame: Engine.Frame) -> ActionResult
    /// `true` while no frame can change anything: the action is paused or
    /// waiting forever. The engine stops its driver when every action is idle.
    var isIdle: Bool { get }
}

extension Action {
    var isIdle: Bool { false }
}
#endif
