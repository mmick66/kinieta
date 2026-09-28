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

    let mainSequence: SequenceAction
    private var waiters: [CheckedContinuation<Void, Never>] = []

    /// Creates an empty timeline for `view` and registers it with the engine.
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
    @discardableResult
    public func animate(_ properties: Property..., duration: TimeInterval = 0) -> Kinieta {
        animate(properties, duration: duration)
    }

    @discardableResult
    public func animate(_ properties: [Property], duration: TimeInterval = 0) -> Kinieta {
        let duration = Kinieta.sanitized(duration, in: "animate(duration:)", allowsInfinity: false)
        mainSequence.pending.add(.animation(AnimationSpec(view, properties, duration: duration)))
        return self
    }

    /// Waits for `time` seconds before the next action.
    ///
    /// A negative or NaN time is treated as zero and logs a warning.
    /// `.infinity` waits until the timeline is cancelled.
    @discardableResult
    public func wait(_ time: TimeInterval) -> Kinieta {
        mainSequence.pending.add(.pause(Kinieta.sanitized(time, in: "wait(_:)", allowsInfinity: true)))
        return self
    }

    /// Delays the start of the previous action by `time` seconds.
    ///
    /// Accepts the same times as ``wait(_:)``.
    @discardableResult
    public func delay(_ time: TimeInterval) -> Kinieta {
        guard let last = mainSequence.pending.popLast() else { return self }
        let time = Kinieta.sanitized(time, in: "delay(_:)", allowsInfinity: true)
        mainSequence.pending.add(.sequence([.pause(time), last]))
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
        let actions = mainSequence.pending.popAllUngrouped()
        guard !actions.isEmpty else { return self }
        mainSequence.pending.add(.group([.sequence(actions)]))
        return self
    }

    /// Runs every action added since the last `then` or `parallel()` together.
    @discardableResult
    public func parallel() -> Kinieta {
        let actions = mainSequence.pending.popAllUngrouped()
        guard !actions.isEmpty else { return self }
        mainSequence.pending.add(.group(actions))
        return self
    }

    /// Appends `times` more copies of everything in the timeline so far.
    @discardableResult
    public func `repeat`(times: Int = 1) -> Kinieta {
        let copy = mainSequence.pending.types
        for _ in 0..<max(times, 0) {
            for type in copy { mainSequence.pending.add(type) }
        }
        return self
    }

    // MARK: Easing

    /// Applies `easing` to the previous animation, including one wrapped by `delay`.
    @discardableResult
    public func easing(_ easing: Easing) -> Kinieta {
        guard let last = mainSequence.pending.popLast() else { return self }
        mainSequence.pending.add(last.withEasing(easing.bezier) ?? last)
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

    /// Calls `block` when the previous action finishes.
    @discardableResult
    public func onComplete(_ block: @escaping Block) -> Kinieta {
        guard let last = mainSequence.pending.popLast() else { return self }
        mainSequence.pending.add(last.withCompletion(block))
        return self
    }

    // MARK: - Controlling the timeline

    /// Stops the timeline where it is. Views keep their current values and no
    /// further completion blocks run.
    public func cancel() {
        guard state == .running || state == .paused else { return }
        mainSequence.isCancelled = true  // also stops it when a group is driving it
        Engine.shared.remove(mainSequence)
        finish(as: .cancelled)
    }

    public func pause() {
        guard state == .running else { return }
        mainSequence.isPaused = true
        state = .paused
    }

    public func resume() {
        guard state == .paused else { return }
        mainSequence.isPaused = false
        state = .running
    }

    /// Suspends until the whole timeline has finished or been cancelled.
    public func finished() async {
        if state == .finished || state == .cancelled { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    /// Moves to a terminal state. The first one wins, so a timeline cancelled
    /// from a completion block never turns into `.finished`.
    private func finish(as state: State) {
        guard self.state == .running || self.state == .paused else { return }
        self.state = state
        let pending = waiters
        waiters = []
        for waiter in pending { waiter.resume() }
    }

    // MARK: - Grouping

    /// Runs several timelines together and returns one handle for all of them.
    /// `completion` runs once, when the last of them finishes.
    @discardableResult
    public static func group(_ handles: [Kinieta], completion: Block? = nil) -> Kinieta {
        let actions = handles.map { $0.mainSequence as Action }
        for action in actions { Engine.shared.remove(action) }
        let handle = Kinieta(view: nil)
        handle.mainSequence.currentAction = GroupAction(running: actions, completion: completion)
        return handle
    }

    @discardableResult
    public static func group(_ handles: Kinieta..., completion: Block? = nil) -> Kinieta {
        group(handles, completion: completion)
    }
}
#endif
