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
/// In debug builds a chain call that has nothing to act on, such as easing
/// after a `wait`, logs a warning with the file and line it was made on. The
/// `file` and `line` parameters carry that location; leave them to their defaults.
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

    /// Where a timeline is in its life. Read it from ``state``.
    public enum State: Sendable {
        /// Playing, or waiting for its next frame. A new handle starts here.
        case running
        /// Stopped by ``pause()`` until ``resume()`` or ``cancel()``.
        case paused
        /// Every action has run. Adding an action starts it again.
        case finished
        /// Stopped by ``cancel()`` or because its view was deallocated. Final:
        /// no further actions or completion blocks run.
        case cancelled
    }

    /// The view this timeline animates. Held weakly: a timeline never keeps a
    /// view alive. When the view is deallocated the timeline is cancelled
    /// before anything else in it runs, even while it is paused or waiting
    /// forever: no further completion blocks are called, `state` becomes
    /// `.cancelled` and ``finished()`` returns.
    public private(set) weak var view: UIView?

    /// The timeline's current state.
    public private(set) var state: State = .running

    public var isRunning: Bool { state == .running }
    public var isPaused: Bool { state == .paused }

    /// The running instance. Its queue is the timeline.
    let mainSequence: SequenceAction
    /// Every step added since the handle was made or last finished, including the ones
    /// already running or done, so `repeat` can copy the whole chain. Emptied
    /// when the timeline ends, which releases the completion blocks it holds.
    var timeline: [ActionType] { mainSequence.queue.steps }
    /// The tasks suspended in `finished()`, keyed so a cancelled one can leave.
    private(set) var waiters: [Int: CheckedContinuation<Void, Never>] = [:]
    private var nextWaiter = 0

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
        mainSequence.handle = self
        mainSequence.completion = { [weak self] in self?.finish(as: .finished) }
        if let view {
            mainSequence.control.target = ViewRef(view)
            mainSequence.control.onViewLost = { [weak self] in self?.cancel() }
            ViewReleaseObserver.observe(view, for: self)
        }
        Engine.shared.add(mainSequence)
    }

    /// A paused timeline, or one waiting forever, that loses its handle can
    /// never move again. The engine lets go of it once nothing is running.
    /// Deferred, since the engine may be mid-frame or releasing this handle itself.
    ///
    /// A paused group handle is one such timeline, but its members have handles
    /// of their own that can still resume or cancel them: the engine takes over
    /// the ones the group was still running, and they keep their state.
    deinit {
        let orphaned = state == .paused ? members : nil
        Task { @MainActor in
            for case let sequence as SequenceAction in orphaned?.releaseMembers() ?? [] {
                sequence.handle?.leaveReleasedGroup()
            }
            Engine.shared.refreshDriver()
        }
    }

    // MARK: - Building the timeline

    /// Animates `properties` to their values over `duration` seconds. A zero
    /// duration sets them on the next frame.
    ///
    /// A negative, NaN or infinite duration is treated as zero and logs a warning.
    ///
    /// A group handle has no view to animate: calling this on one does nothing
    /// and, in debug builds, logs a warning. Animate the grouped timelines instead.
    @discardableResult
    public func animate(
        _ properties: Property..., duration: TimeInterval = 0, file: StaticString = #fileID, line: UInt = #line
    ) -> Kinieta {
        animate(properties, duration: duration, file: file, line: line)
    }

    @discardableResult
    public func animate(
        _ properties: [Property], duration: TimeInterval = 0, file: StaticString = #fileID, line: UInt = #line
    ) -> Kinieta {
        guard !isGroup else {
            Kinieta.ignored(
                "animate(_:duration:) was called on a group handle, which has no view; ignoring it",
                file: file, line: line)
            return self
        }
        let duration = Kinieta.sanitized(duration, in: "animate(duration:)", allowsInfinity: false)
        editUnstarted { $0.add(.animation(AnimationSpec(view, properties, duration: duration))) }
        return self
    }

    /// Waits for `time` seconds before the next action.
    ///
    /// A negative or NaN time is treated as zero and logs a warning.
    /// `.infinity` waits until the timeline is cancelled, without costing
    /// frames. If the handle is released first, the engine releases the timeline.
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
    public func delay(_ time: TimeInterval, file: StaticString = #fileID, line: UInt = #line) -> Kinieta {
        let time = Kinieta.sanitized(time, in: "delay(_:)", allowsInfinity: true)
        editUnstarted { queue in
            guard let last = queue.popLast() else {
                Kinieta.ignored(
                    "delay(_:) has no action to postpone: \(nothingPending(in: queue)); ignoring it",
                    file: file, line: line)
                return
            }
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
    /// only gathers the actions added after `then()`.
    @discardableResult
    public func then(file: StaticString = #fileID, line: UInt = #line) -> Kinieta {
        seal(file: file, line: line)
    }

    /// Seals everything before it into one step. Reading a property should not
    /// change the timeline, and this one cannot locate its caller: its warnings
    /// carry no file and line.
    @available(*, deprecated, renamed: "then()")
    public var then: Kinieta {
        seal(file: nil, line: 0)
    }

    private func seal(file: StaticString?, line: UInt) -> Kinieta {
        editUnstarted { queue in
            let actions = queue.popAllUngrouped()
            guard !actions.isEmpty else {
                Kinieta.ignored(
                    "then() has nothing to seal: \(nothingUngrouped(in: queue)); ignoring it", file: file, line: line)
                return
            }
            queue.add(.group([.sequence(actions)]))
        }
        return self
    }

    /// Runs every action added since the last `then()` or `parallel()` together.
    /// Actions that have already started are left out.
    @discardableResult
    public func parallel(file: StaticString = #fileID, line: UInt = #line) -> Kinieta {
        editUnstarted { queue in
            let actions = queue.popAllUngrouped()
            guard !actions.isEmpty else {
                Kinieta.ignored(
                    "parallel() has nothing to run together: \(nothingUngrouped(in: queue)); ignoring it",
                    file: file, line: line)
                return
            }
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
    public func `repeat`(times: Int = 1, file: StaticString = #fileID, line: UInt = #line) -> Kinieta {
        let replay = children.map { ActionType.sequence($0.timeline) }
        let copy = timeline.map { $0.replacingTimelines(with: replay) }
        editUnstarted { queue in
            if times <= 0 {
                Kinieta.ignored("repeat(times:) was given \(times) times; ignoring it", file: file, line: line)
            } else if copy.isEmpty {
                Kinieta.ignored("repeat(times:) has nothing to repeat: the timeline is empty", file: file, line: line)
            }
            for _ in 0..<max(times, 0) {
                for type in copy { queue.add(type) }
            }
        }
        return self
    }

    /// Edits the steps that have not started yet and hands them back to the
    /// running sequence. Steps already started are out of reach, so easing,
    /// `delay`, `onComplete`, `then()` and `parallel()` never touch them.
    ///
    /// If the edit adds steps to a finished timeline, the timeline starts again.
    ///
    /// The queue is edited in place, so an edit costs only what it changes
    /// however long the timeline is. While it runs, `edit` must reach the
    /// timeline only through the queue it is given.
    private func editUnstarted(_ edit: (inout ActionQueue) -> Void) {
        guard state != .cancelled else { return }
        edit(&mainSequence.queue)
        if state == .finished && !mainSequence.queue.isEmpty { restart() }
    }

    /// Why an edit found no unstarted step in `queue`, for warnings.
    private func nothingPending(in queue: ActionQueue) -> String {
        queue.steps.isEmpty ? "the timeline is empty" : "every action in it has already started"
    }

    /// Why `then()` or `parallel()` found nothing to gather in `queue`, for warnings.
    private func nothingUngrouped(in queue: ActionQueue) -> String {
        queue.isEmpty ? nothingPending(in: queue) : "nothing was added since the last then() or parallel()"
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

    /// Hands this timeline to the engine after its group handle was released
    /// while paused. Does nothing if it has since joined another group or ended.
    private func leaveReleasedGroup() {
        guard owner == nil, state == .running || state == .paused else { return }
        Engine.shared.add(mainSequence)
    }

    // MARK: Easing

    /// Applies `easing` to the previous animation, including one wrapped by `delay`.
    /// Does nothing if the previous step is not an animation or has started.
    @discardableResult
    public func easing(_ easing: Easing, file: StaticString = #fileID, line: UInt = #line) -> Kinieta {
        editUnstarted { queue in
            guard let last = queue.popLast() else {
                Kinieta.ignored(
                    "easing(_:) has no animation to ease: \(nothingPending(in: queue)); ignoring it",
                    file: file, line: line)
                return
            }
            guard let eased = last.withEasing(easing.bezier) else {
                Kinieta.ignored(
                    "easing(_:) follows a \(last.callName), not an animation; ignoring it", file: file, line: line)
                queue.add(last)
                return
            }
            queue.add(eased)
        }
        return self
    }

    @discardableResult
    public func easeIn(_ curve: Easing.Curve = .quad, file: StaticString = #fileID, line: UInt = #line) -> Kinieta {
        easing(.in(curve), file: file, line: line)
    }

    @discardableResult
    public func easeOut(_ curve: Easing.Curve = .quad, file: StaticString = #fileID, line: UInt = #line) -> Kinieta {
        easing(.out(curve), file: file, line: line)
    }

    @discardableResult
    public func easeInOut(_ curve: Easing.Curve = .quad, file: StaticString = #fileID, line: UInt = #line) -> Kinieta {
        easing(.inOut(curve), file: file, line: line)
    }

    // MARK: Completion

    /// Calls `block` when the previous action finishes. Does nothing once
    /// that action has started.
    @discardableResult
    public func onComplete(_ block: @escaping Completion, file: StaticString = #fileID, line: UInt = #line) -> Kinieta {
        editUnstarted { queue in
            guard let last = queue.popLast() else {
                Kinieta.ignored(
                    "onComplete(_:) has no action to follow: \(nothingPending(in: queue)); ignoring it",
                    file: file, line: line)
                return
            }
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
    /// Releasing the handle of a paused timeline lets the engine release the
    /// timeline too, since nothing can resume it. Releasing a paused group
    /// handle leaves the timelines in it paused, each resumable on its own handle.
    public func pause() {
        guard state == .running else { return }
        mainSequence.isPaused = true
        state = .paused
        for child in children { child.pause() }
        Engine.shared.refreshDriver()
    }

    /// Continues a paused timeline. Resuming a group handle also resumes every
    /// timeline in the group; a timeline cannot resume while its group is paused,
    /// unless the group's handle has been released.
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
    ///
    /// Cancelling the awaiting task makes this return straight away, without
    /// waiting for the timeline. The timeline itself carries on: call
    /// ``cancel()`` to stop it too. Other tasks awaiting it keep waiting.
    public func finished() async {
        if state == .finished || state == .cancelled { return }
        let id = nextWaiter
        nextWaiter += 1
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if Task.isCancelled {
                    continuation.resume()
                } else {
                    waiters[id] = continuation
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.waiters.removeValue(forKey: id)?.resume() }
        }
    }

    /// Moves to a terminal state. The first one wins, so a timeline cancelled
    /// from a completion block never turns into `.finished`.
    private func finish(as state: State) {
        guard self.state == .running || self.state == .paused else { return }
        self.state = state
        // Drop what has run: a completion block that captures this handle, or
        // an owner of it, would otherwise keep both alive.
        mainSequence.queue = ActionQueue()
        mainSequence.currentAction = nil
        members = nil
        let pending = waiters.values
        waiters = [:]
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
    /// every timeline in the group. If the handle is released while paused,
    /// the timelines it was running stay paused and leave the group: resume
    /// or cancel each on its own handle. A timeline belongs to at most one group:
    /// one that is already in a group, has finished or was cancelled is left
    /// out with a warning, and a timeline listed twice runs once.
    @discardableResult
    public static func group(_ handles: [Kinieta], completion: Completion? = nil) -> Kinieta {
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
    public static func group(_ handles: Kinieta..., completion: Completion? = nil) -> Kinieta {
        group(handles, completion: completion)
    }
}

/// Cancels the timelines of a view when the view is deallocated. A sequence
/// also checks its view every frame, but a paused timeline, or one waiting
/// forever, gets no frames: without this it would stay `.paused` or
/// `.running`, with its `finished()` callers suspended, until something else
/// started the engine.
///
/// The view holds it as an associated object, so it goes when the view does.
/// It holds the handles weakly and never keeps a timeline alive.
private final class ViewReleaseObserver {
    private struct Entry: Sendable {
        weak var handle: Kinieta?
    }

    nonisolated(unsafe) private static var key: UInt8 = 0

    /// Written on the main actor; read once more by `deinit`, when nothing else can.
    private var entries: [Entry] = []
    /// The count at which released handles are next swept out. Doubling it
    /// keeps adding a handle constant time, however many the view has had.
    private var sweepAt = 16

    @MainActor
    static func observe(_ view: UIView, for handle: Kinieta) {
        let observer: ViewReleaseObserver
        if let existing = objc_getAssociatedObject(view, &key) as? ViewReleaseObserver {
            observer = existing
        } else {
            observer = ViewReleaseObserver()
            objc_setAssociatedObject(view, &key, observer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        observer.entries.append(Entry(handle: handle))
        if observer.entries.count >= observer.sweepAt {
            observer.entries.removeAll { $0.handle == nil }
            observer.sweepAt = max(16, observer.entries.count * 2)
        }
    }

    /// Deferred, as a handle's deinit is: the view may go mid-frame, released
    /// by a completion block. A timeline that has already ended ignores it.
    deinit {
        let entries = entries
        Task { @MainActor in
            for entry in entries { entry.handle?.cancel() }
        }
    }
}
#endif
