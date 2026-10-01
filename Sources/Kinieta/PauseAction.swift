// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit) || os(macOS)
import Foundation

/// Does nothing for a while.
@MainActor
final class PauseAction: Action {

    let duration: TimeInterval
    private var elapsed: TimeInterval = 0

    /// A wait of `.infinity` never ends, so no frame can advance it.
    var isIdle: Bool { duration == .infinity }

    /// Only cancelling its timeline ends a wait of `.infinity`, and the
    /// timeline's sequence checks for a handle that can do that.
    var isAbandoned: Bool { isIdle }

    init(_ duration: TimeInterval) {
        self.duration = duration
    }

    func update(_ frame: Engine.Frame) -> ActionResult {
        elapsed += frame.duration
        if elapsed >= duration {
            // Never hand on more than this frame, whatever the duration was.
            return .finished(overshoot: min(elapsed - duration, frame.duration))
        }
        return .running
    }
}
#endif
