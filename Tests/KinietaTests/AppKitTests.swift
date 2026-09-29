#if os(macOS)
import AppKit
import Testing

@testable import Kinieta

/// The AppKit tracer: `.x`, `.y` and `.alpha` on a layer-backed `NSView`,
/// through the public API, on the engine the UIKit platforms share.
///
/// Frames are stepped by a `ManualFrameDriver`, except in the smoke test on
/// the real display link at the bottom.
@Suite(.serialized, .usesSharedEngine)
@MainActor
struct AppKitTests {

    // Tests must not depend on the Mac's Reduce Motion switch, which some CI runners have on.
    init() {
        Engine.shared.isReduceMotionEnabled = { false }
    }

    private func makeView() -> NSView {
        let view = NSView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        view.wantsLayer = true
        return view
    }

    private func approx(_ a: CGFloat, _ b: CGFloat) -> Bool {
        abs(a - b) < 1e-6
    }

    @Test(.timeLimit(.minutes(1)))
    func animatesXAndAlphaThroughThePublicAPI() async {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        var completed = false
        let handle = view.animate(.x(100), .alpha(0), duration: 1).onComplete { completed = true }
        #expect(handle.view === view)

        frames.step(0.5)
        #expect(approx(view.frame.origin.x, 50))
        #expect(approx(view.alphaValue, 0.5))
        #expect(handle.isRunning && !completed)

        frames.step(0.5)
        #expect(approx(view.frame.origin.x, 100))
        #expect(approx(view.alphaValue, 0))
        #expect(handle.state == .finished && completed)
        await handle.finished()
    }

    @Test func yMovesTheFrameOriginAndKeepsTheSize() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        view.animate(.y(40), duration: 1)
        frames.step(0.25)
        #expect(view.frame == CGRect(x: 0, y: 10, width: 10, height: 10))
        frames.step(0.75)
        #expect(view.frame == CGRect(x: 0, y: 40, width: 10, height: 10))
    }

    @Test func chainsEasingWaitsAndThen() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.animate(.x(100), duration: 1).easeIn()
            .wait(0.5)
            .animate(.alpha(0.2), duration: 0.5)
        frames.step(0.5)
        #expect(view.frame.origin.x < 50)  // eased in: behind linear half way
        frames.step(0.5)
        #expect(approx(view.frame.origin.x, 100))
        frames.step(0.5)
        #expect(approx(view.alphaValue, 1))  // still waiting
        frames.step(0.25)
        #expect(approx(view.alphaValue, 0.6))
        frames.step(0.25)
        #expect(approx(view.alphaValue, 0.2) && handle.state == .finished)
    }

    @Test func aNewerAnimationTakesThePropertyOver() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let older = view.animate(.x(100), .alpha(0), duration: 1)
        frames.step(0.5)
        view.animate(.x(0), duration: 1)
        frames.step(0.25)
        #expect(approx(view.frame.origin.x, 37.5))  // from the 50 on screen back towards 0
        #expect(approx(view.alphaValue, 0.25))  // the older one keeps alpha
        #expect(older.isRunning)
    }

    @Test func reduceMotionSnapsPositionButFadesAlpha() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        Engine.shared.isReduceMotionEnabled = { true }
        let view = makeView()
        view.animate(.x(100), .alpha(0), duration: 1)
        frames.step(0.5)
        #expect(approx(view.frame.origin.x, 100))
        #expect(approx(view.alphaValue, 0.5))
    }

    @Test(.timeLimit(.minutes(1)))
    func releasingTheViewCancelsItsTimelines() async {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        var view: NSView? = makeView()
        let paused = view!.animate(.x(100), duration: 1)
        frames.step()
        paused.pause()
        view = nil
        await paused.finished()
        #expect(paused.state == .cancelled && paused.view == nil)
    }

    @Test(.timeLimit(.minutes(1)))
    func realDisplayLinkRunsATimelineToCompletion() async throws {
        #expect(Engine.shared.driver is Engine.DisplayLinkDriver)
        try #require(!NSScreen.screens.isEmpty, "AppKit hands out display links only for a screen")
        let view = makeView()
        let handle = view.animate(.x(100), .alpha(0), duration: 0.2)
        await handle.finished()
        #expect(handle.state == .finished)
        #expect(approx(view.frame.origin.x, 100))
        #expect(approx(view.alphaValue, 0))
    }
}
#endif
