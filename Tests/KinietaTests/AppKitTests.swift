#if os(macOS)
import AppKit
import Testing

@testable import Kinieta

/// AppKit: position, size, rotation and `.alpha` on a layer-backed `NSView`,
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

    /// Where the view's centre is in its superview, whatever its rotation.
    private func centre(of view: NSView) -> CGPoint {
        view.convert(CGPoint(x: view.bounds.midX, y: view.bounds.midY), to: view.superview)
    }

    private func approx(_ a: CGPoint, _ b: CGPoint) -> Bool {
        approx(a.x, b.x) && approx(a.y, b.y)
    }

    /// A view at (100, 100), 40 by 20, in a 500 point superview.
    private func makeViewInSuperview() -> NSView {
        let superview = NSView(frame: CGRect(x: 0, y: 0, width: 500, height: 500))
        let view = NSView(frame: CGRect(x: 100, y: 100, width: 40, height: 20))
        view.wantsLayer = true
        superview.addSubview(view)
        return view
    }

    @Test func widthAndHeightResizeKeepingTheOrigin() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        view.animate(.width(30), .height(50), duration: 1)
        frames.step(0.5)
        #expect(view.frame == CGRect(x: 0, y: 0, width: 20, height: 30))
        frames.step(0.5)
        #expect(view.frame == CGRect(x: 0, y: 0, width: 30, height: 50))
    }

    @Test func frameAnimatesPositionAndSizeAndANewerXTakesOnlyThePosition() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let older = view.animate(.frame(CGRect(x: 100, y: 40, width: 30, height: 50)), duration: 1)
        frames.step(0.5)
        #expect(view.frame == CGRect(x: 50, y: 20, width: 20, height: 30))
        view.animate(.x(0), duration: 0.5)
        frames.step(0.5)
        #expect(view.frame == CGRect(x: 0, y: 40, width: 30, height: 50))
        #expect(older.state == .finished)
    }

    @Test func aNegativeFrameIsStandardised() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        view.animate(.frame(CGRect(x: 40, y: 40, width: -20, height: -20)), duration: 1)
        frames.step(1)
        #expect(view.frame == CGRect(x: 20, y: 20, width: 20, height: 20))
    }

    @Test func rotationTurnsAboutTheCentre() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeViewInSuperview()
        view.animate(.rotation(degrees: 90), duration: 1)
        frames.step(0.5)
        #expect(approx(view.frameRotation, 45))
        #expect(approx(centre(of: view), CGPoint(x: 120, y: 110)))
        frames.step(0.5)
        #expect(approx(view.frameRotation, 90))
        #expect(approx(centre(of: view), CGPoint(x: 120, y: 110)))
        #expect(view.frame.size == CGSize(width: 40, height: 20))
        #expect(approx(view.x, 100) && approx(view.y, 100))
    }

    @Test func rotationIsUnwrapped() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeViewInSuperview()
        view.animate(.rotation(degrees: 720), duration: 1)
        frames.step(1)
        #expect(view.rotation == 720)  // AppKit's own frameRotation wraps to about 0
        view.animate(.rotation(degrees: 630), duration: 1)
        frames.step(0.5)
        #expect(approx(view.rotation, 675))
        #expect(approx(view.frameRotation, -45))  // turned back, not forward through 0
        frames.step(0.5)
        #expect(approx(centre(of: view), CGPoint(x: 120, y: 110)))
    }

    @Test func rotationReadsAnAngleSetOutsideKinieta() {
        let view = makeViewInSuperview()
        view.rotation = 400
        #expect(view.rotation == 400)
        view.frameCenterRotation = 30
        #expect(approx(view.rotation, 30))
    }

    @Test func positionAndSizeAnimateAlongsideARotation() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeViewInSuperview()
        view.animate(.rotation(degrees: 90), .x(200), .width(60), duration: 1)
        frames.step(0.5)
        // Unrotated, the view would be at (150, 100), 50 by 20: centred on (175, 110).
        #expect(approx(centre(of: view), CGPoint(x: 175, y: 110)))
        #expect(approx(view.frameRotation, 45))
        frames.step(0.5)
        #expect(approx(centre(of: view), CGPoint(x: 230, y: 110)))
        #expect(approx(view.frameRotation, 90))
        #expect(approx(view.x, 200) && approx(view.y, 100))
        #expect(view.frame.size == CGSize(width: 60, height: 20))
    }

    @Test func reduceMotionSnapsSizeAndRotation() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        Engine.shared.isReduceMotionEnabled = { true }
        let view = makeViewInSuperview()
        view.animate(.width(60), .rotation(degrees: 90), duration: 1)
        frames.step(0.5)
        #expect(view.frame.width == 60)
        #expect(approx(view.rotation, 90))
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
