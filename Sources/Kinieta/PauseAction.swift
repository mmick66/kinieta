// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit)
import Foundation

/// Does nothing for a while.
@MainActor
final class PauseAction: Action {

    let duration: TimeInterval
    let completion: Block?
    private var elapsed: TimeInterval = 0

    init(_ duration: TimeInterval, completion: Block?) {
        self.duration = duration
        self.completion = completion
    }

    func update(_ frame: Engine.Frame) -> ActionResult {
        elapsed += frame.duration
        if elapsed >= duration {
            completion?()
            return .finished(overshoot: elapsed - duration)
        }
        return .running
    }
}
#endif
