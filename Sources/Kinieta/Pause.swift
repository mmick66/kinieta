// Kinieta — MIT License. See LICENSE.

import Foundation

/// Does nothing for a while.
@MainActor
final class Pause: Action {

    let duration: TimeInterval
    let complete: Block?
    private var elapsed: TimeInterval = 0

    init(_ duration: TimeInterval, complete: Block?) {
        self.duration = duration
        self.complete = complete
    }

    func update(_ frame: Engine.Frame) -> ActionResult {
        elapsed += frame.duration
        if elapsed >= duration {
            complete?()
            return .finished
        }
        return .running
    }
}
