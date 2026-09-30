// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit) || os(macOS)
import Foundation

/// Replays its steps, one cycle after another, until its timeline is cancelled.
///
/// Each cycle is a fresh sequence made from the same descriptions, so a loop
/// holds one copy of its steps however long it runs. A cycle that takes no
/// time, such as one whose durations are all zero or snap under Reduce Motion,
/// would otherwise replay forever inside one frame: at most one cycle starts per frame.
@MainActor
final class LoopAction: Action {

    let types: [ActionType]
    let control: TimelineControl
    private var cycle: SequenceAction?
    /// The engine frame the latest cycle started on.
    private var startFrame: Int?

    /// Idle while the cycle is, as when it waits forever. Between cycles it
    /// is not: the next one starts on the next frame.
    var isIdle: Bool { cycle?.isIdle == true }
    var isAbandoned: Bool { cycle?.isAbandoned == true }

    init(_ types: [ActionType], control: TimelineControl) {
        self.types = types
        self.control = control
    }

    func update(_ frame: Engine.Frame) -> ActionResult {
        var frame = frame
        while true {
            if cycle == nil {
                let now = Engine.shared.frameNumber
                guard startFrame != now else { return .running }
                startFrame = now
                cycle = SequenceAction(types, control: control, isNested: true)
            }
            switch cycle!.update(frame) {
            case .running:
                return .running
            case .finished(let overshoot):
                cycle = nil
                // A completion block may have cancelled or paused the timeline.
                if control.isCancelled { return .finished(overshoot: 0) }
                if control.isPaused { return .running }
                // Start the next cycle with the rest of the frame, as a sequence
                // starts its next action.
                guard overshoot > 0 else { return .running }
                frame = Engine.Frame(overshoot)
            }
        }
    }
}
#endif
