#if canImport(UIKit) || os(macOS)
import Testing

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

@testable import Kinieta

/// Timelines composed from `Step` values: the same timelines the chain builds,
/// frame for frame, plus what only steps can do. Runs on `UIView` and `NSView`.
@Suite(.serialized, .usesSharedEngine)
@MainActor
struct StepTests {

    // Tests must not depend on the host's accessibility settings; see EngineTests.
    init() {
        Engine.shared.isReduceMotionEnabled = { false }
    }

    private func makeView() -> PlatformView {
        let view = PlatformView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        #if os(macOS)
        view.wantsLayer = true
        #endif
        return view
    }

    private func approx(_ a: CGFloat, _ b: CGFloat) -> Bool {
        abs(a - b) < 1e-6
    }

    /// What a frame leaves on screen and in the log.
    private struct Snapshot: Equatable {
        let x, y, width, alpha: CGFloat
        let log: [String]
        let state: Kinieta.State
    }

    /// Frame lengths that land both inside and exactly on step boundaries.
    private static let frameLengths: [TimeInterval] = [1.0 / 60, 0.05, 0.1, 0.033, 0.2, 0.017]

    /// Runs the timeline `chain` builds and the one `steps` builds side by side,
    /// each on its own view, and expects the same values, completion order and
    /// state on every one of `frameCount` frames. Both builders log through the
    /// function they are given.
    private func expectEquivalent(
        frameCount: Int = 120,
        chain: (PlatformView, @escaping (String) -> Void) -> Kinieta,
        steps: (PlatformView, @escaping (String) -> Void) -> Kinieta,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let (chainView, stepView) = (makeView(), makeView())
        var (chainLog, stepLog): ([String], [String]) = ([], [])
        let chainHandle = chain(chainView) { chainLog.append($0) }
        let stepHandle = steps(stepView) { stepLog.append($0) }
        defer {
            chainHandle.cancel()
            stepHandle.cancel()
        }

        func snapshot(_ view: PlatformView, _ log: [String], _ handle: Kinieta) -> Snapshot {
            Snapshot(x: view.x, y: view.y, width: view.width, alpha: view.alpha, log: log, state: handle.state)
        }
        for frame in 0..<frameCount {
            frames.step(Self.frameLengths[frame % Self.frameLengths.count])
            let expected = snapshot(chainView, chainLog, chainHandle)
            let actual = snapshot(stepView, stepLog, stepHandle)
            guard expected == actual else {
                Issue.record("frame \(frame): chain \(expected), steps \(actual)", sourceLocation: sourceLocation)
                return
            }
        }
    }

    // MARK: - The same timelines as the chain

    @Test func aSequenceWithDelayEasingAndCompletionsMatchesTheChain() {
        expectEquivalent(
            chain: { view, log in
                view.animate(.x(100), duration: 0.5)
                    .easeInOut(.cubic)
                    .onComplete { log("moved") }
                    .wait(0.2)
                    .animate(.alpha(0.5), .width(40), duration: 0.3, easing: .out(.back))
                    .delay(0.15)
                    .onComplete { log("faded") }
                    .animate(.y(30), duration: 0.25)
                    .onComplete { log("dropped") }
            },
            steps: { view, log in
                view.run {
                    Step.animate(.x(100), duration: 0.5, easing: .inOut(.cubic))
                        .onComplete { log("moved") }
                    Step.wait(0.2)
                    Step.animate(.alpha(0.5), .width(40), duration: 0.3, easing: .out(.back))
                        .delay(0.15)
                        .onComplete { log("faded") }
                    Step.animate(.y(30), duration: 0.25)
                        .onComplete { log("dropped") }
                }
            })
    }

    @Test func animateParametersMatchTheChain() {
        expectEquivalent(
            chain: { view, log in
                view.animate(.x(80), duration: 0.4, delay: 0.3, easing: .in(.quart)).onComplete { log("done") }
            },
            steps: { view, log in
                view.run(
                    Step.animate(.x(80), duration: 0.4, delay: 0.3, easing: .in(.quart)).onComplete { log("done") })
            })
    }

    @Test func parallelMatchesTheChain() {
        expectEquivalent(
            chain: { view, log in
                view.animate(.x(100), duration: 0.5)
                    .onComplete { log("x") }
                    .animate(.y(60), duration: 0.8, easing: .out(.quad))
                    .delay(0.1)
                    .onComplete { log("y") }
                    .parallel()
                    .onComplete { log("both") }
                    .animate(.alpha(0), duration: 0.3)
                    .onComplete { log("faded") }
            },
            steps: { view, log in
                view.run {
                    Step.parallel {
                        Step.animate(.x(100), duration: 0.5)
                            .onComplete { log("x") }
                        Step.animate(.y(60), duration: 0.8, easing: .out(.quad))
                            .delay(0.1)
                            .onComplete { log("y") }
                    }
                    .onComplete { log("both") }
                    Step.animate(.alpha(0), duration: 0.3)
                        .onComplete { log("faded") }
                }
            })
    }

    @Test func aDelayedParallelMatchesTheChain() {
        expectEquivalent(
            chain: { view, log in
                view.animate(.x(50), duration: 0.3)
                    .animate(.alpha(0.2), duration: 0.6)
                    .parallel()
                    .delay(0.25)
                    .onComplete { log("both") }
            },
            steps: { view, log in
                view.run(
                    Step.parallel {
                        Step.animate(.x(50), duration: 0.3)
                        Step.animate(.alpha(0.2), duration: 0.6)
                    }
                    .delay(0.25)
                    .onComplete { log("both") })
            })
    }

    @Test func repeatTimesMatchesTheChain() {
        expectEquivalent(
            frameCount: 200,
            chain: { view, log in
                view.animate(.x(100), duration: 0.3, easing: .inOut(.sine))
                    .animate(.x(0), duration: 0.2)
                    .onComplete { log("lap") }
                    .wait(0.1)
                    .repeat(times: 3)
                    .onComplete { log("done") }
            },
            steps: { view, log in
                view.run(
                    Step.sequence {
                        Step.animate(.x(100), duration: 0.3, easing: .inOut(.sine))
                        Step.animate(.x(0), duration: 0.2)
                            .onComplete { log("lap") }
                        Step.wait(0.1)
                    }
                    .repeat(times: 3)
                    .onComplete { log("done") })
            })
    }

    @Test func repeatForeverMatchesTheChain() {
        expectEquivalent(
            frameCount: 300,
            chain: { view, log in
                view.animate(.x(100), duration: 0.3)
                    .onComplete { log("out") }
                    .animate(.x(0), .alpha(0.5), duration: 0.25, easing: .out(.cubic))
                    .onComplete { log("back") }
                    .repeatForever()
            },
            steps: { view, log in
                view.run(
                    Step.sequence {
                        Step.animate(.x(100), duration: 0.3)
                            .onComplete { log("out") }
                        Step.animate(.x(0), .alpha(0.5), duration: 0.25, easing: .out(.cubic))
                            .onComplete { log("back") }
                    }
                    .repeatForever())
            })
    }

    // MARK: - Repeating without copies

    @Test func repeatHoldsOneCopyWithACount() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        var laps = 0
        let lap = Step.sequence {
            Step.animate(.x(10), duration: 0.5)
            Step.animate(.x(0), duration: 0.5)
                .onComplete { laps += 1 }
        }
        let handle = view.run(lap.repeat(times: 1_000_000))
        defer { handle.cancel() }
        #expect(handle.timeline.map(\.description) == ["Repeat (1000001 × 1)"])
        frames.step(1, count: 50)
        #expect(laps == 50)
        #expect(handle.timeline.count == 1)
        #expect(handle.isRunning)
    }

    @Test func repeatPlaysTheStepTimesMoreAndThenEnds() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        var calls = 0
        let handle = view.run(Step.call { calls += 1 }.repeat(times: 4))
        frames.step()
        #expect(calls == 5)
        #expect(handle.state == .finished)
    }

    @Test func repeatWithANegativeOrZeroCountPlaysOnce() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        var calls = 0
        let step = Step.call { calls += 1 }
        let view = makeView()
        view.run {
            step.repeat(times: 0)
            step.repeat(times: -3)
        }
        frames.step()
        #expect(calls == 2)
    }

    @Test func aCycleThatStartsWithACallRunsItOnTheFrameThePreviousCycleEnds() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        var log: [String] = []
        let handle = view.run(
            Step.sequence {
                Step.call { log.append("start \(view.x)") }
                Step.animate(.x(100), duration: 0.5)
            }
            .repeat(times: 1))
        frames.step(0.25)
        #expect(log == ["start 0.0"])
        frames.step(0.25)
        #expect(log == ["start 0.0", "start 100.0"])
        frames.step(0.5)
        #expect(handle.state == .finished)
    }

    // MARK: - One step, many views

    @Test func oneStepRunsOnTwoViewsIndependently() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let (first, second) = (makeView(), makeView())
        var finished: [String] = []
        let slide = Step.animate(.x(100), duration: 1).onComplete { finished.append("slide") }

        let firstHandle = first.run(slide)
        frames.step(0.5)
        let secondHandle = second.run(slide)
        #expect(firstHandle.view === first && secondHandle.view === second)
        frames.step(0.25)
        #expect(approx(first.x, 75))
        #expect(approx(second.x, 25))

        firstHandle.cancel()
        frames.step(0.25)
        #expect(approx(first.x, 75))
        #expect(approx(second.x, 50))
        frames.step(0.5)
        #expect(approx(second.x, 100))
        #expect(finished == ["slide"])
        #expect(firstHandle.state == .cancelled && secondHandle.state == .finished)
    }

    @Test func aStaggeredForLoopAnimatesEveryView() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let views = (0..<3).map { _ in makeView() }
        let rise = Step.animate(.y(50), duration: 0.5)
        for (index, view) in views.enumerated() {
            view.run(rise.delay(Double(index) * 0.25))
        }
        frames.step(0.5)
        #expect(views.map(\.y) == [50, 25, 0])
        frames.step(0.5)
        #expect(views.map(\.y) == [50, 50, 50])
    }

    @Test func runningOnAViewKeepsTheViewLossRule() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        var completed = false
        weak var released: PlatformView?
        // AppKit autoreleases a layer-backed view's layer, which holds on to the view.
        let handle = autoreleasepool {
            let view = makeView()
            released = view
            return view.run(Step.animate(.x(100), duration: 1).onComplete { completed = true })
        }
        frames.step(0.5)
        #expect(released == nil)
        frames.step(0.5)
        #expect(handle.state == .cancelled)
        #expect(!completed)
    }

    // MARK: - The builder

    @Test func ifAndElseChooseTheirSteps() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        var log: [String] = []
        func steps(fade: Bool, slide: Bool) -> Step {
            Step.sequence {
                if fade {
                    Step.call { log.append("fade") }
                }
                if slide {
                    Step.call { log.append("slide") }
                } else {
                    Step.call { log.append("stay") }
                }
            }
        }
        let (first, second) = (makeView(), makeView())
        first.run(steps(fade: true, slide: false))
        second.run(steps(fade: false, slide: true))
        frames.step()
        #expect(log == ["fade", "stay", "slide"])
    }

    @Test func aForLoopGivesOneStepPerElement() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        var order: [Int] = []
        let handle = view.run {
            Step.parallel {
                for index in 0..<4 {
                    Step.call { order.append(index) }
                        .delay(Double(index) * 0.1)
                }
            }
            Step.animate(.x(40), duration: 0.2)
        }
        frames.step(0.05)
        #expect(order == [0])
        frames.step(0.1)
        #expect(order == [0, 1])
        frames.step(0.15)
        #expect(order == [0, 1, 2, 3])
        frames.step(0.1)
        #expect(approx(view.x, 20))
        frames.step(0.1)
        #expect(handle.state == .finished)
    }

    @Test func anEmptyBuilderFinishesOnTheNextFrameLikeAnEmptyTimeline() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let (view, other) = (makeView(), makeView())
        let empty = view.run {}
        let emptyTimeline = Kinieta(for: other)
        #expect(empty.isRunning && emptyTimeline.isRunning)
        frames.step()
        #expect(empty.state == .finished && emptyTimeline.state == .finished)
    }

    @Test func emptySequenceAndParallelStepsEndAtOnce() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        var log: [String] = []
        let view = makeView()
        let handle = view.run {
            Step.sequence {}
            Step.parallel {}
            Step.call { log.append("after") }
        }
        frames.step()
        #expect(log == ["after"])
        #expect(handle.state == .finished)
    }

    // MARK: - Modifiers

    @Test func onCompleteTwiceRunsBothBlocksInOrder() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        var log: [String] = []
        let view = makeView()
        view.run(
            Step.animate(.x(10), duration: 0.5)
                .onComplete { log.append("first") }
                .onComplete { log.append("second") })
        frames.step(0.5)
        #expect(log == ["first", "second"])
    }

    @Test func onCompleteAddsToASequenceThatEndsWithACall() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        var log: [String] = []
        let view = makeView()
        view.run(
            Step.sequence {
                Step.wait(0.5)
                Step.call { log.append("inside") }
            }
            .onComplete { log.append("after") })
        frames.step(0.5)
        #expect(log == ["inside", "after"])
    }

    @Test func delayTwiceAddsTheDelays() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        view.run(Step.animate(.x(100), duration: 1, delay: 0.25).delay(0.5).delay(0.25))
        frames.step(1)
        #expect(view.x == 0)
        frames.step(0.5)
        #expect(approx(view.x, 50))
    }

    @Test func modifiersLeaveTheOriginalStepAsItWas() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        var calls = 0
        let step = Step.call { calls += 1 }
        _ = step.repeat(times: 5).delay(1).onComplete { calls += 100 }
        let view = makeView()
        view.run(step)
        frames.step()
        #expect(calls == 1)
    }

    @Test func badDurationsAreTreatedAsZero() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.run {
            Step.animate(.x(10), duration: -1)
            Step.animate(.y(10), duration: .infinity, delay: .nan)
            Step.wait(-2)
            Step.animate(.alpha(0), duration: .nan).delay(-1)
        }
        frames.step()
        #expect(view.x == 10 && view.y == 10 && view.alpha == 0)
        #expect(handle.state == .finished)
    }

    // MARK: - Extending a handle

    @Test func runAppendsToARunningTimeline() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.animate(.x(100), duration: 1)
        frames.step(0.5)
        #expect(handle.run(Step.animate(.x(0), duration: 1)) === handle)
        frames.step(0.5)
        #expect(approx(view.x, 100))
        frames.step(0.5)
        #expect(approx(view.x, 50))
        frames.step(0.5)
        #expect(handle.state == .finished)
    }

    @Test func runRestartsAFinishedTimeline() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.run(Step.animate(.x(100), duration: 0.5))
        frames.step(0.5)
        #expect(handle.state == .finished)
        handle.run(Step.animate(.x(0), duration: 0.5))
        #expect(handle.isRunning)
        frames.step(0.25)
        #expect(approx(view.x, 50))
        frames.step(0.25)
        #expect(handle.state == .finished)
    }

    @Test func runLeavesACancelledTimelineCancelled() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.animate(.x(100), duration: 1)
        handle.cancel()
        handle.run(Step.animate(.x(50), duration: 0.5))
        frames.step(1)
        #expect(handle.state == .cancelled)
        #expect(view.x == 0)
    }

    @Test func chainCallsActOnARunStep() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        var log: [String] = []
        view.run(Step.animate(.x(100), duration: 1))
            .delay(0.5)
            .onComplete { log.append("done") }
        frames.step(1)
        #expect(approx(view.x, 50))
        frames.step(0.5)
        #expect(log == ["done"])
    }

    // Ignored calls are reported in debug builds only.
    #if DEBUG
    @Test func runOnAGroupHandleIgnoresAnimationsButRunsCalls() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let previous = Kinieta.ignoredCallSink
        defer { Kinieta.ignoredCallSink = previous }
        var ignored: [IgnoredCall] = []
        Kinieta.ignoredCallSink = { ignored.append($0) }

        var log: [String] = []
        let view = makeView()
        let group = Kinieta.group(view.animate(.x(100), duration: 0.5))
        group.run(Step.animate(.y(100), duration: 0.5))
        group.run(Step.wait(0.5).onComplete { log.append("waited") })
        #expect(
            ignored.map(\.message) == [
                "run(_:) was given a step that animates, on a group handle, which has no view; ignoring it"
            ])
        frames.step(0.5)
        frames.step(0.5)
        #expect(log == ["waited"])
        #expect(view.y == 0)
        #expect(group.state == .finished)
    }

    @Test func runAfterRepeatForeverIsIgnored() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let previous = Kinieta.ignoredCallSink
        defer { Kinieta.ignoredCallSink = previous }
        var ignored: [IgnoredCall] = []
        Kinieta.ignoredCallSink = { ignored.append($0) }

        let view = makeView()
        let handle = view.run(Step.animate(.x(10), duration: 1).repeatForever())
        defer { handle.cancel() }
        handle.run(Step.wait(1))
        #expect(ignored.map(\.message) == ["run(_:) was called after repeatForever(), which never ends; ignoring it"])
        #expect(handle.timeline.count == 1)
    }
    #endif

    // MARK: - Names

    @Test func stepIsReachableThroughTheClassName() {
        let step: Kinieta.Step = Kinieta.Step.wait(0)
        #expect(Kinieta.Step.self == Step.self)
        #expect(step.action.description == "Pause (0.0)")
    }
}
#endif
