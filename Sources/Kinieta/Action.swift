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
#elseif os(macOS)
import AppKit
#endif

#if canImport(UIKit) || os(macOS)

/// A weak reference to the view an action targets, so a pending timeline never
/// keeps a view alive. An animation whose view has gone finishes immediately.
struct ViewRef {
    weak var view: PlatformView?
    init(_ view: PlatformView?) { self.view = view }
}

/// An animation waiting to run: which view, what to change, and how.
struct AnimationSpec {
    var target: ViewRef
    var properties: [Property]
    var duration: TimeInterval
    /// `nil` means linear.
    var easing: Bezier?

    init(_ view: PlatformView?, _ properties: [Property], duration: TimeInterval, easing: Bezier? = nil) {
        self.target = ViewRef(view)
        self.properties = properties
        self.duration = duration
        self.easing = easing
    }
}

/// The description of an action before it runs. A timeline is a tree of these;
/// they are turned into live `Action` objects when their turn comes.
enum ActionType: CustomStringConvertible {
    case animation(AnimationSpec)
    case pause(TimeInterval)
    case group([ActionType])
    case sequence([ActionType])
    /// The live group behind a `Kinieta.group` handle. Its members are other
    /// handles' sequences, already running, so it cannot be copied.
    case timelines(GroupAction)
    /// Replays its steps until the timeline is cancelled. It never finishes,
    /// so nothing can follow it.
    case loop([ActionType])
    /// Runs a block, such as one from `onComplete`, and takes no time. It
    /// follows the step it completes in a sequence, so the sequence's check
    /// between its children is what keeps it from running once the timeline
    /// is cancelled or has lost its view.
    case call(Kinieta.Completion)

    /// A step that `onComplete` follows with a call reads as the step it completes.
    var description: String {
        if let (step, _) = completed { return step.description }
        switch self {
        case .animation(let spec):
            return "Animation (\(spec.properties.map(\.name).joined(separator: " ")))"
        case .pause(let duration):
            return "Pause (\(duration))"
        case .group(let types):
            return "Group (\(types.count))"
        case .sequence(let types):
            return "Sequence (\(types.count))"
        case .timelines:
            return "Timelines"
        case .loop(let types):
            return "Loop (\(types.count))"
        case .call:
            return "Call"
        }
    }

    /// The step `onComplete` wrapped and the block it follows it with, or `nil`
    /// if this is not such a step.
    var completed: (step: ActionType, block: Kinieta.Completion)? {
        guard case .sequence(let types) = self, types.count == 2, case .call(let block) = types[1] else { return nil }
        return (types[0], block)
    }

    /// The same step, followed by a call to `completion` instead of any block
    /// `onComplete` gave it before.
    func withCompletion(_ completion: @escaping Kinieta.Completion) -> ActionType {
        .sequence([completed?.step ?? self, .call(completion)])
    }

    /// `true` for a group, including one `onComplete` follows with a block.
    /// `then()` and `parallel()` gather nothing before it.
    var isGroup: Bool {
        if case .group = completed?.step ?? self { return true }
        return false
    }

    /// The same action with every live group of timelines replaced by `replay`,
    /// a copy that can run again. Used by `repeat` on a group handle.
    func replacingTimelines(with replay: [ActionType]) -> ActionType {
        switch self {
        case .animation, .pause, .call:
            return self
        case .group(let types):
            return .group(types.map { $0.replacingTimelines(with: replay) })
        case .sequence(let types):
            return .sequence(types.map { $0.replacingTimelines(with: replay) })
        case .timelines:
            return .group(replay)
        case .loop(let types):
            return .loop(types.map { $0.replacingTimelines(with: replay) })
        }
    }

    /// The same action with its last animation eased by `bezier`, looking
    /// inside the sequence `delay` wraps it in and past the block `onComplete`
    /// follows it with; nil if there is no animation to ease.
    func withEasing(_ bezier: Bezier) -> ActionType? {
        if let (step, block) = completed {
            return step.withEasing(bezier).map { .sequence([$0, .call(block)]) }
        }
        switch self {
        case .animation(var spec):
            spec.easing = bezier
            return .animation(spec)
        case .sequence(var types):
            guard let last = types.popLast(), let eased = last.withEasing(bezier) else { return nil }
            types.append(eased)
            return .sequence(types)
        case .pause, .group, .timelines, .loop, .call:
            return nil
        }
    }

    /// The live action, answering to `control`: nested sequences and groups
    /// stop as soon as the timeline they belong to is cancelled or paused.
    @MainActor
    func makeAction(control: TimelineControl) -> Action {
        switch self {
        case .animation(let spec):
            return PropertyAnimation(spec)
        case .pause(let duration):
            return PauseAction(duration)
        case .group(let types):
            return GroupAction(pending: types, control: control)
        case .sequence(let types):
            return SequenceAction(types, control: control)
        case .timelines(let action):
            action.control = control
            return action
        case .loop(let types):
            return LoopAction(types, control: control)
        case .call(let block):
            return CallAction(block)
        }
    }
}

/// Whether a timeline has been cancelled or paused, and the view it runs,
/// shared by its main sequence and every sequence and group nested in it. A
/// completion block can cancel or pause the timeline, or release its view, at
/// any depth, so each of them checks this after every child it updates and
/// stops there, in that same frame.
@MainActor
final class TimelineControl {
    var isCancelled = false
    var isPaused = false

    /// The view of the timeline, if it has one. Once the view is deallocated
    /// the timeline cancels itself before running anything else and calls
    /// `onViewLost`, so its handle can end as cancelled.
    var target: ViewRef?
    var onViewLost: Kinieta.Completion?

    var isHalted: Bool { isCancelled || isPaused }

    var hasLostView: Bool {
        target.map { $0.view == nil } ?? false
    }

    /// Cancels the timeline if its view has gone. Returns `true` if it has.
    func cancelIfViewIsGone() -> Bool {
        guard hasLostView else { return false }
        isCancelled = true
        onViewLost?()
        return true
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
    /// `true` while idle with nothing left that could wake it: every handle
    /// that could resume or cancel it is gone. The engine lets go of it.
    var isAbandoned: Bool { get }
}

extension Action {
    var isIdle: Bool { false }
    var isAbandoned: Bool { false }
}
#endif
