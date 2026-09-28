#if canImport(UIKit)
import Testing
import UIKit

@testable import Kinieta

/// Scaling tests. Each one times the same work at two sizes and checks that
/// four times the work takes well under sixteen times as long, the ratio a
/// quadratic cost would give. Part of `EngineTests` so they run serialized
/// with the other tests that drive `Engine.shared`.
extension EngineTests {

    // MARK: Performance

    @Test func presetEasingsShareOneBakedTable() {
        let curves: [Easing.Curve] = [.sine, .quad, .cubic, .quart, .quint, .expo, .back]
        let easings: [(Easing.Curve) -> Easing] = [Easing.in, Easing.out, Easing.inOut]
        for curve in curves {
            for easing in easings {
                let first = easing(curve).bezier.points
                let second = easing(curve).bezier.points
                #expect(tableAddress(first) == tableAddress(second))
            }
        }
    }

    @Test func longTimelinesBuildAndRunInLinearTime() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        #expect(scalesLinearly(small: 2_500, large: 10_000) { count in buildAndRunTimeline(of: count, frames) })
    }

    @Test func manyTimelinesFinishingTogetherRunInLinearTime() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        #expect(scalesLinearly(small: 2_500, large: 10_000) { count in runTimelines(count, frames) })
    }

    private func tableAddress(_ points: [Bezier.Point]) -> UnsafeRawPointer? {
        points.withUnsafeBufferPointer { UnsafeRawPointer($0.baseAddress) }
    }

    /// One timeline of `count` eased animations, in groups of four, run to the end.
    private func buildAndRunTimeline(of count: Int, _ frames: ManualFrameDriver) {
        let view = UIView()
        let handle = Kinieta(for: view)
        for index in 0..<count {
            handle.animate(.x(CGFloat(index)), duration: 0.001).easeInOut(.back)
            if index % 4 == 3 { handle.parallel() }
        }
        while handle.state != .finished && frames.isRunning { frames.step() }
        #expect(handle.state == .finished)
    }

    /// `count` timelines that all finish on the same frame.
    private func runTimelines(_ count: Int, _ frames: ManualFrameDriver) {
        let view = UIView()
        let handles = (0..<count).map { _ in view.animate(.x(1), duration: 0.01) }
        while frames.isRunning { frames.step() }
        #expect(handles.allSatisfy { $0.state == .finished })
    }

    /// Whether `work` at the `large` size (four times `small`) takes less than
    /// eight times as long. Each size is timed three times and the best kept.
    private func scalesLinearly(small: Int, large: Int, _ work: (Int) -> Void) -> Bool {
        func best(_ count: Int) -> Duration {
            (0..<3).map { _ in ContinuousClock().measure { work(count) } }.min()!
        }
        let smallTime = best(small)
        let largeTime = best(large)
        print("\(small): \(smallTime), \(large): \(largeTime), ratio \(largeTime / smallTime)")
        return largeTime < smallTime * 8
    }
}
#endif
