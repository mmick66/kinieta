#if canImport(UIKit)
import Testing
import UIKit

@testable import Kinieta

/// A newer animation of a property takes it over from an older one still
/// running on the same view, driven through the public API with a `ManualFrameDriver`.
@Suite(.serialized, .usesSharedEngine)
@MainActor
struct InterruptionTests {

    init() {
        Engine.shared.isReduceMotionEnabled = { false }
    }

    private func makeView() -> UIView {
        UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
    }

    @Test func aNewerAnimationTakesOverFromWhereTheViewIs() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        var olderCompleted = false
        let older = view.animate(.x(100), .alpha(0), duration: 1).onComplete { olderCompleted = true }
        frames.step(0.5)
        #expect(approx(view.x, 50))

        // The older timeline runs first in the frame and writes 75 before the
        // newer one starts; the newer one still starts from the 50 on screen.
        let newer = view.animate(.x(0), duration: 1)
        frames.step(0.25)
        #expect(approx(view.x, 37.5))
        #expect(approx(view.alpha, 0.25, 1e-6))

        // The older animation keeps its alpha and completes on schedule.
        frames.step(0.25)
        #expect(approx(view.x, 25))
        #expect(view.alpha == 0)
        #expect(olderCompleted && older.state == .finished)
        #expect(newer.isRunning)

        frames.step(0.5)
        #expect(view.x == 0)
        #expect(newer.state == .finished)
    }

    @Test func noFrameShowsTheOlderAnimationsValueAfterTheTakeover() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        view.animate(.x(100), duration: 2)
        frames.step(0.1, count: 10)
        view.animate(.x(0), duration: 1)
        var previous = view.x
        for _ in 0..<12 {
            frames.step(0.1)
            #expect(view.x < previous || view.x == 0)
            previous = view.x
        }
        #expect(view.x == 0)
    }

    @Test func theTakeoverDoesNotDependOnWhichTimelineRunsFirst() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        // The newer animation is the group's first member, so it runs before
        // the older one in every frame.
        view.animate(.x(0), duration: 1).delay(0.5)
            .animate(.x(100), .alpha(0), duration: 1)
            .parallel()
        frames.step(0.5)
        #expect(approx(view.x, 50))
        frames.step(0.25)
        #expect(approx(view.x, 37.5))
        #expect(approx(view.alpha, 0.25, 1e-6))
    }

    @Test func anAnimationWithEveryPropertyTakenKeepsItsSchedule() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        var steps: [String] = []
        let older = view.animate(.x(100), duration: 1).onComplete { steps.append("older x") }
            .animate(.y(100), duration: 1)
        frames.step(0.5)
        view.animate(.x(0), duration: 0.25).onComplete { steps.append("newer x") }
        frames.step(0.25)
        #expect(steps == ["newer x"])
        #expect(view.x == 0)
        frames.step(0.25)
        #expect(steps == ["newer x", "older x"])
        #expect(view.x == 0)  // the older animation no longer writes x
        frames.step(0.5)
        #expect(approx(view.y, 50))
        frames.step(0.5)
        #expect(view.y == 100 && older.state == .finished)
    }

    @Test func aNewerPositionTakesOnlyThePositionFromAnOlderFrame() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        view.animate(.frame(CGRect(x: 100, y: 100, width: 110, height: 110)), duration: 1)
        frames.step(0.5)
        view.animate(.x(0), .width(10), duration: 0.5)
        frames.step(0.25)
        #expect(approx(view.x, 25) && approx(view.width, 35))
        #expect(approx(view.y, 75) && approx(view.height, 85))
        frames.step(0.25)
        #expect(view.x == 0 && view.width == 10)
        #expect(view.y == 100 && view.height == 110)
    }

    @Test func aNewerFrameTakesPositionAndSizeFromOlderAnimations() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        view.animate(.x(100), .height(50), .alpha(0), duration: 1)
        frames.step(0.5)
        view.animate(.frame(CGRect(x: 0, y: 0, width: 20, height: 20)), duration: 0.5)
        frames.step(0.25)
        // Started from x 50 and height 30, where the older animation had them.
        #expect(approx(view.x, 25) && approx(view.height, 25))
        frames.step(0.25)
        #expect(view.untransformedFrame == CGRect(x: 0, y: 0, width: 20, height: 20))
        #expect(view.alpha == 0)
    }

    @Test func aPausedAnimationDoesNotWriteATakenPropertyWhenResumed() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let older = view.animate(.x(100), .alpha(0), duration: 1)
        frames.step(0.5)
        older.pause()
        view.animate(.x(0), duration: 0.5)
        frames.step(0.5)
        #expect(view.x == 0)
        older.resume()
        frames.step(0.5)
        #expect(view.x == 0 && view.alpha == 0)
        #expect(older.state == .finished)
    }

    @Test func animationsOfOtherViewsAndOtherPropertiesAreLeftAlone() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView(), other = makeView()
        view.animate(.x(100), duration: 1)
        other.animate(.x(100), duration: 1)
        frames.step(0.5)
        view.animate(.y(100), duration: 0.5)
        other.animate(.custom(\.layer.shadowOpacity, to: 1), duration: 0.5)
        frames.step(0.5)
        #expect(view.x == 100 && view.y == 100)
        #expect(other.x == 100 && other.layer.shadowOpacity == 1)
    }

    @Test func aConstraintIsTakenOverByAnotherViewsTimeline() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 100))
        let badge = UIView(), label = UIView()
        container.addSubview(badge)
        container.addSubview(label)
        let width = badge.widthAnchor.constraint(equalToConstant: 0)
        width.isActive = true
        badge.animate(.constant(width, to: 100), duration: 1)
        frames.step(0.5)
        label.animate(.constant(width, to: 0), duration: 1)
        frames.step(0.25)
        #expect(approx(width.constant, 37.5))
        frames.step(0.75)
        #expect(width.constant == 0)
    }

    @Test func aFinishedAnimationGivesItsPropertiesBack() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        view.animate(.x(100), duration: 0.5)
        frames.step(0.25)
        #expect(PropertyAnimation.owners.owner(of: view, .x) != nil)
        frames.step(0.25)
        #expect(PropertyAnimation.owners.owner(of: view, .x) == nil)
    }

    @Test func aCancelledTimelineGivesItsPropertiesBack() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.animate(.x(100), duration: 1)
        frames.step(0.25)
        handle.cancel()
        #expect(PropertyAnimation.owners.owner(of: view, .x) == nil)
    }
}
#endif
