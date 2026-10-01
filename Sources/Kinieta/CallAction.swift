// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit) || os(macOS)
import Foundation

/// Runs a block, such as one from `onComplete`, and finishes at once with
/// the whole frame left over, so it costs no frame.
@MainActor
final class CallAction: Action {

    let block: Kinieta.Completion

    init(_ block: @escaping Kinieta.Completion) {
        self.block = block
    }

    func update(_ frame: Engine.Frame) -> ActionResult {
        block()
        return .finished(overshoot: frame.duration)
    }
}
#endif
