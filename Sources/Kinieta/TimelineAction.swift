// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit) || os(macOS)
import Foundation

/// The root of a handle's timeline, which the engine or a group handle drives.
///
/// It owns the timeline's control and runs the timeline's steps as a plain
/// `SequenceAction`, and when they have run, finishes the handle. Every
/// sequence, group and loop nested in it shares its control.
@MainActor
final class TimelineAction: Action {

    /// The timeline's steps.
    let sequence = SequenceAction()

    /// Ends the handle when the timeline has run, but not once it is cancelled.
    var completion: Kinieta.Completion?

    /// The handle whose timeline this is; `nil` once the handle has been released.
    weak var handle: Kinieta?

    var control: TimelineControl { sequence.control }

    var isIdle: Bool { sequence.isIdle }

    /// Idle with its handle gone: nothing can resume or cancel it any more.
    var isAbandoned: Bool { handle == nil && sequence.isAbandoned }

    init(_ types: [ActionType] = [], completion: Kinieta.Completion? = nil) {
        sequence.queue = ActionQueue(types)
        self.completion = completion
    }

    func update(_ frame: Engine.Frame) -> ActionResult {
        let result = sequence.update(frame)
        // A sequence finishes with its timeline cancelled only when it has stopped short.
        if result.isFinished && !control.isCancelled { completion?() }
        return result
    }
}
#endif
