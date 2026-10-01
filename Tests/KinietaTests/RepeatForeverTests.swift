#if canImport(UIKit)
import Testing
import UIKit

@testable import Kinieta

/// `repeatForever()`: a timeline that loops until it is cancelled, driven frame
/// by frame with a `ManualFrameDriver`.
@Suite(.serialized, .usesSharedEngine)
@MainActor
struct RepeatForeverTests {

    // Tests must not depend on the host's accessibility settings; see EngineTests.
    init() {
        Engine.shared.isReduceMotionEnabled = { false }
    }

    private func makeView() -> UIView {
        UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
    }

    private func descriptions(_ k: Kinieta) -> [String] {
        k.timeline.map { $0.description }
    }

    @Test func loopsUntilCancelledWithAConstantNumberOfSteps() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        var laps = 0
        let handle = view.animate(.x(100), duration: 1)
            .animate(.x(0), duration: 1)
            .onComplete { laps += 1 }
            .repeatForever()
        #expect(descriptions(handle) == ["Animation (x)", "Animation (x)", "Loop (2)"])
        for lap in 1...50 {
            frames.step(0.5)
            #expect(approx(view.frame.origin.x, 50, 0.5))
            frames.step(0.5)
            #expect(approx(view.frame.origin.x, 100))
            frames.step(1)
            #expect(approx(view.frame.origin.x, 0))
            #expect(laps == lap)
            #expect(handle.isRunning)
        }
        #expect(handle.timeline.count == 3)

        handle.cancel()
        #expect(handle.state == .cancelled)
        #expect(!frames.isRunning)
        frames.step(1, count: 5)
        #expect(approx(view.frame.origin.x, 0))
        #expect(laps == 50)
    }

    @Test func repeatForeverAfterTheFirstFrameReplaysTheWholeChain() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.animate(.x(100), duration: 1).animate(.x(0), duration: 1)
        defer { handle.cancel() }
        frames.step(1.5)
        handle.repeatForever()
        frames.step(0.5)
        #expect(approx(view.frame.origin.x, 0))
        frames.step(1)
        #expect(approx(view.frame.origin.x, 100))
        frames.step(1)
        #expect(approx(view.frame.origin.x, 0))
        #expect(handle.isRunning)
    }

    @Test(.timeLimit(.minutes(1)))
    func finishedReturnsOnlyOnCancel() async {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.animate(.x(100), duration: 0.5).repeatForever()
        var returned = false
        let waiter = Task {
            await handle.finished()
            returned = true
        }
        while handle.waiters.isEmpty { await Task.yield() }
        frames.step(0.25, count: 40)
        await Task.yield()
        #expect(!returned && handle.isRunning)
        handle.cancel()
        await waiter.value
        #expect(returned && handle.state == .cancelled)
        withExtendedLifetime(view) {}
    }

    @Test func releasingTheViewCancelsTheLoop() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        var view: UIView? = makeView()
        let handle = view!.animate(.x(100), duration: 1).repeatForever()
        frames.step(1, count: 3)
        view = nil
        frames.step()
        #expect(handle.state == .cancelled)
    }

    @Test func aBlockThatReleasesTheViewEndsTheLoopInThatFrame() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        var view: UIView? = makeView()
        var cycles = 0
        let handle = view!.animate(.x(100)).onComplete {
            cycles += 1
            if cycles == 3 { view = nil }
        }
        .repeatForever()
        frames.step(count: 2)  // the chain and the first cycle, then the second cycle
        #expect(cycles == 3)
        #expect(handle.state == .cancelled)
    }

    @Test func aZeroDurationCyclePlaysOncePerFrame() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        var cycles = 0
        let handle = view.animate(.x(100)).animate(.x(0)).onComplete { cycles += 1 }.repeatForever()
        defer { withExtendedLifetime(view) { handle.cancel() } }
        frames.step()
        #expect(cycles == 2)  // the chain itself, then the loop's first cycle
        frames.step(count: 10)
        #expect(cycles == 12)
        #expect(handle.isRunning)
    }

    @Test func aZeroLengthWaitPlaysOncePerFrame() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        var cycles = 0
        let handle = view.wait(0).onComplete { cycles += 1 }.repeatForever()
        defer { withExtendedLifetime(view) { handle.cancel() } }
        frames.step(count: 10)
        #expect(cycles == 11)
    }

    @Test func aCycleSnappedByReduceMotionPlaysOncePerFrame() {
        Engine.shared.isReduceMotionEnabled = { true }
        defer { Engine.shared.isReduceMotionEnabled = { false } }
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        var cycles = 0
        let handle = view.animate(.x(100), duration: 1)
            .animate(.x(0), duration: 1)
            .onComplete { cycles += 1 }
            .repeatForever()
        defer { handle.cancel() }
        frames.step(count: 10)
        #expect(cycles == 11)
        #expect(view.frame.origin.x == 0)
    }

    @Test func pauseHoldsTheLoopAndResumeContinuesIt() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.animate(.x(100), duration: 1).animate(.x(0), duration: 1).repeatForever()
        defer { handle.cancel() }
        frames.step(1, count: 2)  // the chain itself
        frames.step(0.5)  // half way through the first cycle
        handle.pause()
        #expect(!frames.isRunning)
        frames.step(1, count: 3)
        #expect(approx(view.frame.origin.x, 50, 0.5))
        handle.resume()
        frames.step(0.5)
        #expect(approx(view.frame.origin.x, 100))
        frames.step(1)
        #expect(approx(view.frame.origin.x, 0))
        #expect(handle.isRunning)
    }

    @Test func cancelFromACompletionBlockInTheLoopStopsIt() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        var laps = 0
        let handle = view.animate(.x(100), duration: 1)
        handle.onComplete {
            laps += 1
            if laps == 3 { handle.cancel() }
        }
        .animate(.x(0), duration: 1)
        .repeatForever()
        frames.step(1, count: 10)
        #expect(laps == 3)
        #expect(handle.state == .cancelled)
        #expect(approx(view.frame.origin.x, 100))
    }

    @Test func aNewerAnimationInterruptsTheCycleAndTheNextAnimationTakesItBack() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let loop = view.animate(.x(100), duration: 1).animate(.x(0), duration: 1).repeatForever()
        defer { loop.cancel() }
        frames.step(1, count: 2)  // the chain itself
        frames.step(0.5)
        #expect(approx(view.frame.origin.x, 50, 0.5))
        view.animate(.x(300), duration: 0.25)
        frames.step(0.25)
        #expect(approx(view.frame.origin.x, 300))
        frames.step(0.25)  // the loop's first animation ends without writing x again
        #expect(approx(view.frame.origin.x, 300))
        frames.step(0.5)  // its second animation starts from where the view is
        #expect(approx(view.frame.origin.x, 150, 0.5))
        frames.step(0.5)
        #expect(approx(view.frame.origin.x, 0))
        frames.step(1)
        #expect(approx(view.frame.origin.x, 100))
    }

    @Test func aGroupRunningALoopNeverCompletes() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let a = makeView(), b = makeView()
        var completed = false
        let looping = a.animate(.x(100), duration: 1).animate(.x(0), duration: 1).repeatForever()
        let once = b.animate(.y(100), duration: 1)
        let group = Kinieta.group(looping, once) { completed = true }
        frames.step(1, count: 5)
        #expect(once.state == .finished && looping.isRunning && group.isRunning)
        #expect(!completed)

        group.pause()
        #expect(looping.isPaused && !frames.isRunning)
        group.resume()
        frames.step(1)
        #expect(approx(a.frame.origin.x, 0))

        group.cancel()
        #expect(looping.state == .cancelled && group.state == .cancelled)
        #expect(!completed)
    }

    @Test func repeatForeverOnAGroupHandleReplaysTheGroup() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let a = makeView(), b = makeView()
        var completions = 0
        let group = Kinieta.group(
            a.animate(.x(100), duration: 0.5).animate(.x(0), duration: 0.5),
            b.animate(.y(100), duration: 0.5).animate(.y(0), duration: 0.5)
        ) { completions += 1 }
        .repeatForever()
        defer { group.cancel() }
        for lap in 1...5 {
            frames.step(0.5)
            #expect(approx(a.frame.origin.x, 100) && approx(b.frame.origin.y, 100))
            frames.step(0.5)
            #expect(approx(a.frame.origin.x, 0) && approx(b.frame.origin.y, 0))
            #expect(completions == lap && group.isRunning)
        }
        #expect(group.timeline.count == 2)
    }

    @Test func aHugeRepeatCountIsCapped() {
        let k = Kinieta(for: makeView()).animate(.x(1), duration: 1).repeat(times: .max)
        defer { k.cancel() }
        #expect(k.timeline.count == Kinieta.maximumRepeatCount + 1)
    }

    // MARK: Ignored chain calls

    #if DEBUG
    /// The warnings `body` raises about chain calls that did nothing.
    private func ignoredCalls(_ body: () -> Void) -> [IgnoredCall] {
        let previous = Kinieta.ignoredCallSink
        defer { Kinieta.ignoredCallSink = previous }
        var calls: [IgnoredCall] = []
        Kinieta.ignoredCallSink = { calls.append($0) }
        body()
        return calls
    }

    @Test func callsAfterRepeatForeverAreReportedAndChangeNothing() {
        let k = Kinieta(for: makeView()).animate(.x(1), duration: 1).repeatForever()
        defer { k.cancel() }
        let before = descriptions(k)
        let calls = ignoredCalls {
            k.animate(.y(1), duration: 1).wait(1).delay(1).easeIn().onComplete {}
                .then().parallel().repeat(times: 2).repeatForever()
        }
        let calledAfter = [
            "animate(_:duration:)", "wait(_:)", "delay(_:)", "easing(_:)", "onComplete(_:)", "then()", "parallel()",
            "repeat(times:)", "repeatForever()",
        ]
        #expect(
            calls.map(\.message)
                == calledAfter.map { "\($0) was called after repeatForever(), which never ends; ignoring it" })
        #expect(descriptions(k) == before)
    }

    @Test func aWarningAfterRepeatForeverCarriesTheCallSite() {
        let k = Kinieta(for: makeView()).animate(.x(1), duration: 1).repeatForever()
        defer { k.cancel() }
        let line: UInt = #line + 1
        let calls = ignoredCalls { k.wait(1) }
        #expect(calls.map(\.site) == [IgnoredCall.Site(fileID: #fileID, line: line)])
    }

    @Test func repeatForeverOnAnEmptyTimelineIsReported() {
        let k = Kinieta(for: makeView())
        defer { k.cancel() }
        let calls = ignoredCalls { k.repeatForever() }
        #expect(calls.map(\.message) == ["repeatForever() has nothing to repeat: the timeline is empty"])
        #expect(k.timeline.isEmpty)
    }

    @Test func aLoopingChainRaisesNoWarnings() {
        var handles: [Kinieta] = []
        let calls = ignoredCalls {
            handles.append(
                makeView().animate(.alpha(0.3), duration: 0.8).easeInOut(.sine)
                    .animate(.alpha(1), duration: 0.8).easeInOut(.sine).delay(0.2)
                    .onComplete {}
                    .repeatForever())
            handles.append(Kinieta.group(makeView().animate(.x(1), duration: 1)).wait(1).repeatForever())
        }
        for handle in handles { handle.cancel() }
        #expect(calls.isEmpty)
    }
    #endif
}
#endif
