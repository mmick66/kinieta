#if canImport(UIKit) || os(macOS)
import Foundation
import Testing

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

@testable import Kinieta

/// What one frame, step or call costs, so a refactor can be compared before
/// and after. Not a pass/fail test: the timings depend on the machine, so the
/// suite runs only when `KINIETA_BENCH=1` is set. `scripts/bench.sh` sets it
/// and runs the suite in release mode.
///
/// Each benchmark runs its work several times and prints the best run, which
/// is the one least disturbed by the rest of the machine. Only the frames or
/// calls are timed, not building the views and timelines.
@Suite(
    .serialized, .usesSharedEngine,
    .enabled(
        if: ProcessInfo.processInfo.environment["KINIETA_BENCH"] == "1", "Set KINIETA_BENCH=1, or run scripts/bench.sh")
)
@MainActor
struct Benchmarks {

    /// How many times each benchmark runs; the best run is reported.
    static let runs = 10

    static let frameDuration: TimeInterval = 1.0 / 120

    // Benchmarks must not depend on the host's Reduce Motion switch, which would snap every animation.
    init() {
        Engine.shared.isReduceMotionEnabled = { false }
    }

    // MARK: Benchmarks

    @Test func framesOfManyViews() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        report("1,000 views: .x .y .alpha .background, 1 s", per: "frame") {
            let views = (0..<1_000).map { _ in makeView() }
            let handles = views.map {
                $0.animate(.x(100), .y(100), .alpha(0.5), .background(.blue), duration: 1)
            }
            let (time, count) = runToTheEnd(frames)
            #expect(handles.allSatisfy { $0.state == .finished })
            withExtendedLifetime(views) {}
            return (time, count)
        }
    }

    @Test func stepBoundariesOfOneTimeline() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let steps = 10_000
        report("1 timeline of 10,000 steps of 1 ms", per: "step") {
            let view = makeView()
            let handle = Kinieta(for: view)
            for index in 0..<steps { handle.animate(.x(CGFloat(index % 100)), duration: 0.001) }
            let (time, _) = runToTheEnd(frames)
            #expect(handle.state == .finished)
            return (time, steps)
        }
    }

    @Test func framesOfNestedTimelines() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        report("500 timelines: parallel(), delay, onComplete", per: "frame") {
            var completions = 0
            let views = (0..<500).map { _ in makeView() }
            let handles = views.map { view in
                view.animate(.x(50), duration: 0.4).delay(0.1).onComplete { completions += 1 }
                    .animate(.y(50), duration: 0.5)
                    .animate(.alpha(0.5), duration: 0.3).delay(0.2)
                    .parallel().delay(0.05).onComplete { completions += 1 }
                    .then()
                    .animate(.x(0), duration: 0.2).delay(0.05)
                    .animate(.y(0), duration: 0.3).onComplete { completions += 1 }
                    .parallel().onComplete { completions += 1 }
            }
            let (time, count) = runToTheEnd(frames)
            #expect(handles.allSatisfy { $0.state == .finished })
            #expect(completions == 4 * views.count)
            return (time, count)
        }
    }

    @Test(arguments: [
        ("preset .inOut(.cubic)", Easing.inOut(.cubic).bezier),
        ("custom (0.16, 0.73, 0.89, 0.24)", Bezier(0.16, 0.73, 0.89, 0.24)),
    ])
    func bezierProgress(_ name: String, _ bezier: Bezier) {
        let calls = 1_000_000
        report("Bezier.progress(at:), \(name)", per: "call") {
            var sum = 0.0
            let time = ContinuousClock().measure {
                for index in 0..<calls { sum += bezier.progress(at: (Double(index) + 0.5) / Double(calls)) }
            }
            #expect(sum > 0)
            return (time, calls)
        }
    }

    @Test(arguments: ["sRGB", "Display P3"])
    func lchInterpolation(_ gamut: String) throws {
        var from: PlatformColor = .red
        var to: PlatformColor = .blue
        if gamut == "Display P3" {
            from = PlatformColor(displayP3Red: 1, green: 0, blue: 0, alpha: 1)
            to = PlatformColor(displayP3Red: 0, green: 1, blue: 0, alpha: 1)
        }
        let interpolate = try #require(ColorMath.interpolator(from: from, to: to, mode: .lch, appearance: nil))
        let calls = 1_000_000
        report("LCH colour interpolation, \(gamut)", per: "call") {
            let time = ContinuousClock().measure {
                for index in 0..<calls { consume(interpolate((CGFloat(index) + 0.5) / CGFloat(calls))) }
            }
            return (time, calls)
        }
    }

    // MARK: Helpers

    private func makeView() -> PlatformView {
        let view = PlatformView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        #if canImport(UIKit)
        view.backgroundColor = .red
        #else
        view.wantsLayer = true
        view.layer?.backgroundColor = PlatformColor.red.cgColor
        #endif
        return view
    }

    /// Steps 120 fps frames until the engine has nothing left to run, and
    /// returns how long that took and how many frames it was.
    private func runToTheEnd(_ frames: ManualFrameDriver) -> (Duration, Int) {
        var count = 0
        let time = ContinuousClock().measure {
            while frames.isRunning {
                frames.step(Self.frameDuration)
                count += 1
            }
        }
        return (time, count)
    }

    /// Runs `work` `runs` times and prints the best time per `unit`. `work`
    /// returns the time it measured and how many units that time covers.
    private func report(_ name: String, per unit: String, _ work: () -> (Duration, Int)) {
        let best = (0..<Self.runs).map { _ in
            let (time, count) = work()
            return nanoseconds(time) / Double(count)
        }.min()!
        // The same separators on every machine, so logs from different locales compare.
        let cost = best.formatted(
            .number.locale(Locale(identifier: "en_US")).grouping(.automatic)
                .precision(.fractionLength(best < 100 ? 1 : 0)))
        let label = name.padding(toLength: 56, withPad: " ", startingAt: 0)
        print("[bench] \(label) \(String(repeating: " ", count: max(0, 10 - cost.count)))\(cost) ns/\(unit)")
    }

    private func nanoseconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) * 1e9 + Double(duration.components.attoseconds) / 1e9
    }
}

/// Keeps a value the optimizer would otherwise be free to drop.
@inline(never)
private func consume<T>(_ value: T) {}
#endif
