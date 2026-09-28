// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit)
import UIKit
import os

/// A handle to one view's timeline.
///
/// Every call on `UIView.animate` or `UIView.wait` creates a handle whose
/// timeline starts on the next frame. Chain further calls to extend it, then
/// keep the handle to `cancel()`, `pause()`, `resume()` or `await finished()`.
///
/// A handle can be extended at any time. Actions added to a running timeline
/// play after the ones already there; actions added to a finished timeline
/// start it again on the next frame. A cancelled timeline stays cancelled.
///
/// ```swift
/// square.animate(.x(374), .background(.systemPink), duration: 1.0)
///       .easeInOut(.back)
///       .wait(1.0)
///       .animate(.x(74), duration: 0.5)
///       .onComplete { print("back home") }
/// ```
@MainActor
public final class Kinieta {

    public enum State: Sendable {
        case running
        case paused
        case finished
        case cancelled
    }

    /// The view this timeline animates. Held weakly: a timeline never keeps a
    /// view alive, and it finishes on its own when the view goes away.
    public private(set) weak var view: UIView?

    public private(set) var state: State = .running

    public var isRunning: Bool { state == .running }
    public var isPaused: Bool { state == .paused }

    /// The running instance. Its queue holds the steps of `timeline` that have
    /// not started yet, always as a suffix of `timeline`.
    let mainSequence: SequenceAction
    /// Every step added since the handle was made or last finished, including the ones
    /// already running or done, so `repeat` can copy the whole chain. Emptied
    /// when the timeline ends, which releases the completion blocks it holds.
    private(set) var timeline: [ActionType] = []
    private var waiters: [CheckedContinuation<Void, Never>] = []

    /// The group driving this timeline, if any. A timeline is driven either by
    /// the engine or by exactly one group, never both.
    private weak var owner: Kinieta?
    /// The timelines this group handle drives. Empty for an ordinary timeline.
    private var children: [Kinieta] = []
    /// The action running this group handle's members; `nil` for an ordinary timeline.
    private var members: GroupAction?
    /// `true` for a handle made by `group`, which has no view of its own.
    private var isGroup = false

    /// Creates an empty timeline for `view` and registers it with the engine.
    ///
    /// An empty timeline finishes on the next frame. Adding to it afterwards
    /// starts it again, so the handle can be built later.
    public convenience init(for view: UIView) {
        self.init(view: view)
    }

    init(view: UIView?) {
        self.view = view
        mainSequence = SequenceAction()
        mainSequence.completion = { [weak self] in self?.finish(as: .finished) }
        Engine.shared.add(mainSequence)
    }

    // MARK: - Building the timeline

    /// Animates `properties` to their values over `duration` seconds. A zero
    /// duration sets them on the next frame.
    ///
    /// A negative, NaN or infinite duration is treated as zero and logs a warning.
    ///
    /// A group handle has no view to animate: calling this on one does nothing
    /// and logs a warning. Animate the grouped timelines instead.
    @discardableResult
    public func animate(_ properties: Property..., duration: TimeInterval = 0) -> Kinieta {
        animate(properties, duration: duration)
    }

    @discardableResult
    public func animate(_ properties: [Property], duration: TimeInterval = 0) -> Kinieta {
        guard !isGroup else {
            Kinieta.logger.warning("animate(_:duration:) was called on a group handle, which has no view; ignoring it")
            return self
        }
        let duration = Kinieta.sanitized(duration, in: "animate(duration:)", allowsInfinity: false)
        editUnstarted { $0.add(.animation(AnimationSpec(view, properties, duration: duration))) }
        return self
    }

    /// Waits for `time` seconds before the next action.
    ///
    /// A negative or NaN time is treated as zero and logs a warning.
    /// `.infinity` waits until the timeline is cancelled, without costing frames.
    @discardableResult
    public func wait(_ time: TimeInterval) -> Kinieta {
        let time = Kinieta.sanitized(time, in: "wait(_:)", allowsInfinity: true)
        editUnstarted { $0.add(.pause(time)) }
        return self
    }

    /// Delays the start of the previous action by `time` seconds. Does nothing
    /// once that action has started.
    ///
    /// Accepts the same times as ``wait(_:)``.
    @discardableResult
    public func delay(_ time: TimeInterval) -> Kinieta {
        let time = Kinieta.sanitized(time, in: "delay(_:)", allowsInfinity: true)
        editUnstarted { queue in
            guard let last = queue.popLast() else { return }
            queue.add(.sequence([.pause(time), last]))
        }
        return self
    }

    private static let logger = Logger(subsystem: "Kinieta", category: "Timeline")

    /// `time` if it is a usable duration, otherwise zero with a warning.
    /// Only waits may last forever; an endless animation would never move.
    static func sanitized(_ time: TimeInterval, in call: String, allowsInfinity: Bool) -> TimeInterval {
        if time >= 0 && (time.isFinite || allowsInfinity) { return time }
        logger.warning("\(call, privacy: .public) was given \(time, privacy: .public) seconds; using 0")
        return 0
    }

    /// Seals everything before it into one step, so a following `parallel()`
    /// only gathers the actions added after `then`.
    public var then: Kinieta {
        editUnstarted { queue in
            let actions = queue.popAllUngrouped()
            guard !actions.isEmpty else { return }
            queue.add(.group([.sequence(actions)]))
        }
        return self
    }

    /// Runs every action added since the last `then` or `parallel()` together.
    /// Actions that have already started are left out.
    @discardableResult
    public func parallel() -> Kinieta {
        editUnstarted { queue in
            let actions = queue.popAllUngrouped()
            guard !actions.isEmpty else { return }
            queue.add(.group(actions))
        }
        return self
    }

    /// Appends `times` more copies of everything in the timeline so far,
    /// including actions that are already running or done.
    ///
    /// A finished timeline forgets its actions, so repeating one that was
    /// extended after it finished copies only what was added since.
    ///
    /// On a group handle each copy replays what the grouped timelines hold at
    /// the time of the call. The copies run on the group handle, so they
    /// answer to it rather than to the grouped handles.
    @discardableResult
    public func `repeat`(times: Int = 1) -> Kinieta {
        let replay = children.map { ActionType.sequence($0.timeline) }
        let copy = timeline.map { $0.replacingTimelines(with: replay) }
        editUnstarted { queue in
            for _ in 0..<max(times, 0) {
                for type in copy { queue.add(type) }
            }
        }
        return self
    }

    /// Edits the steps that have not started yet and hands them back to the
    /// running sequence. Steps already started are out of reach, so easing,
    /// `delay`, `onComplete`, `then` and `parallel` never touch them.
    ///
    /// If the edit adds steps to a finished timeline, the timeline starts again.
    private func editUnstarted(_ edit: (inout ActionQueue) -> Void) {
        guard state != .cancelled else { return }
        let started = timeline.count - mainSequence.pending.count
        var queue = mainSequence.pending
        edit(&queue)
        timeline.replaceSubrange(started..., with: queue.types)
        mainSequence.pending = queue
        if state == .finished && !queue.isEmpty { restart() }
    }

    /// Runs a finished timeline again from the steps waiting in its queue.
    /// A timeline whose group is still running rejoins it; otherwise it
    /// leaves the group and the engine drives it.
    private func restart() {
        state = .running
        if let owner, owner.members?.adopt(mainSequence) == true {
            if owner.isPaused { pause() }
            Engine.shared.refreshDriver()
            return
        }
        owner?.children.removeAll { $0 === self }
        owner = nil
        Engine.shared.add(mainSequence)
    }

    // MARK: Easing

    /// Applies `easing` to the previous animation, including one wrapped by `delay`.
    @discardableResult
    public func easing(_ easing: Easing) -> Kinieta {
        editUnstarted { queue in
            guard let last = queue.popLast() else { return }
            queue.add(last.withEasing(easing.bezier) ?? last)
        }
        return self
    }

    @discardableResult
    public func easeIn(_ curve: Easing.Curve = .quad) -> Kinieta {
        easing(.in(curve))
    }

    @discardableResult
    public func easeOut(_ curve: Easing.Curve = .quad) -> Kinieta {
        easing(.out(curve))
    }

    @discardableResult
    public func easeInOut(_ curve: Easing.Curve = .quad) -> Kinieta {
        easing(.inOut(curve))
    }

    // MARK: Completion

    /// Calls `block` when the previous action finishes. Does nothing once
    /// that action has started.
    @discardableResult
    public func onComplete(_ block: @escaping Block) -> Kinieta {
        editUnstarted { queue in
            guard let last = queue.popLast() else { return }
            queue.add(last.withCompletion(block))
        }
        return self
    }

    // MARK: - Controlling the timeline

    /// Stops the timeline where it is. Views keep their current values and no
    /// further completion blocks run.
    ///
    /// Cancelling a group handle also cancels every timeline in the group.
    public func cancel() {
        guard state == .running || state == .paused else { return }
        mainSequence.isCancelled = true  // also stops it when a group is driving it
        Engine.shared.remove(mainSequence)
        finish(as: .cancelled)
        for child in children { child.cancel() }
        Engine.shared.refreshDriver()  // a cancelled child finishes its group's next frame
    }

    /// Holds the timeline where it is. Pausing a group handle also pauses every
    /// timeline in the group.
    ///
    /// While every timeline is paused the engine stops requesting frames.
    public func pause() {
        guard state == .running else { return }
        mainSequence.isPaused = true
        state = .paused
        for child in children { child.pause() }
        Engine.shared.refreshDriver()
    }

    /// Continues a paused timeline. Resuming a group handle also resumes every
    /// timeline in the group; a timeline cannot resume while its group is paused.
    public func resume() {
        guard state == .paused, owner?.isPaused != true else { return }
        mainSequence.isPaused = false
        state = .running
        for child in children { child.resume() }
        Engine.shared.refreshDriver()
    }

    /// Suspends until the whole timeline has finished or been cancelled.
    ///
    /// Actions added while waiting are waited for too. Actions added to a
    /// finished timeline start it again, and a later call waits for them.
    public func finished() async {
        if state == .finished || state == .cancelled { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    /// Moves to a terminal state. The first one wins, so a timeline cancelled
    /// from a completion block never turns into `.finished`.
    private func finish(as state: State) {
        guard self.state == .running || self.state == .paused else { return }
        self.state = state
        // Drop what has run: a completion block that captures this handle, or
        // an owner of it, would otherwise keep both alive.
        timeline = []
        mainSequence.pending = ActionQueue()
        mainSequence.currentAction = nil
        members = nil
        let pending = waiters
        waiters = []
        for waiter in pending { waiter.resume() }
    }

    // MARK: - Grouping

    /// Runs several timelines together and returns one handle for all of them.
    /// `completion` runs once, when the last of them finishes; it is the same
    /// as calling `onComplete` on the returned handle.
    ///
    /// The group is the first step of the returned handle's timeline, so the
    /// handle chains like any other: `delay` postpones the whole group,
    /// `wait` and `onComplete` follow it, and `repeat` replays it. The handle
    /// has no view, so `animate` on it does nothing.
    ///
    /// Cancelling, pausing or resuming the returned handle does the same to
    /// every timeline in the group. A timeline belongs to at most one group:
    /// one that is already in a group, has finished or was cancelled is left
    /// out with a warning, and a timeline listed twice runs once.
    @discardableResult
    public static func group(_ handles: [Kinieta], completion: Block? = nil) -> Kinieta {
        var members: [Kinieta] = []
        for child in handles where !members.contains(where: { $0 === child }) {
            if child.owner != nil {
                logger.warning("group(_:) was given a timeline that is already in a group; leaving it out")
            } else if child.state == .finished || child.state == .cancelled {
                logger.warning("group(_:) was given a timeline that has already ended; leaving it out")
            } else {
                members.append(child)
            }
        }
        // Register the group before taking its members off the engine, so the
        // engine never empties and restarts its clock in between.
        let handle = Kinieta(view: nil)
        handle.isGroup = true
        for child in members {
            child.owner = handle
            Engine.shared.remove(child.mainSequence)
        }
        let action = GroupAction(running: members.map { $0.mainSequence })
        handle.children = members
        handle.members = action
        handle.editUnstarted { $0.add(.timelines(action, completion: completion)) }
        return handle
    }

    @discardableResult
    public static func group(_ handles: Kinieta..., completion: Block? = nil) -> Kinieta {
        group(handles, completion: completion)
    }
}
#endif
