#if canImport(UIKit)
import Foundation

@testable import Kinieta

/// A frame driver the test steps by hand, so timelines built through the
/// public `Kinieta` API run deterministically without a display link.
///
/// ```swift
/// let frames = ManualFrameDriver.install()
/// defer { frames.uninstall() }
/// let handle = view.animate(.x(100), duration: 1)
/// frames.step(0.5)  // view is half way
/// ```
///
/// Like a display link, the driver only delivers frames while the engine has
/// actions registered: `step` does nothing when `isRunning` is `false`.
@MainActor
final class ManualFrameDriver: FrameDriver {
    private var onFrame: ((Engine.Frame) -> Void)?
    private var previous: (any FrameDriver)?

    var isRunning: Bool { onFrame != nil }

    /// Makes this driver the source of frames for `Engine.shared`.
    static func install() -> ManualFrameDriver {
        let driver = ManualFrameDriver()
        driver.previous = Engine.shared.driver
        Engine.shared.driver = driver
        return driver
    }

    /// Restores the driver that was in place before `install()`.
    func uninstall() {
        guard let previous else { return }
        Engine.shared.driver = previous
        self.previous = nil
    }

    func start(onFrame: @escaping (Engine.Frame) -> Void) {
        guard self.onFrame == nil else { return }
        self.onFrame = onFrame
    }

    func stop() {
        onFrame = nil
    }

    /// Delivers `count` frames of `duration` seconds each.
    func step(_ duration: TimeInterval = 1.0 / 60, count: Int = 1) {
        for _ in 0..<count {
            onFrame?(Engine.Frame(duration))
        }
    }
}
#endif
