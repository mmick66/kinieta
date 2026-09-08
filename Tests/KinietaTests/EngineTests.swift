import Testing
import UIKit

@testable import Kinieta

/// Engine tests. Actions are driven with synthetic `Engine.Frame` values so no
/// display link is involved, except in the end-to-end tests at the bottom.
///
/// Serialized because every test shares `Engine.shared` and its display link.
@Suite(.serialized)
@MainActor
struct EngineTests {

    private func frame(_ dt: TimeInterval) -> Engine.Frame {
        Engine.Frame(0, dt)
    }

    private func makeView() -> UIView {
        UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
    }

    private func animation(
        _ view: UIView, _ properties: [Property], duration: TimeInterval,
        easing: Easing? = nil, complete: Block? = nil
    ) -> Animation {
        Animation(ViewRef(view), properties: properties, duration: duration, easing: easing?.bezier, complete: complete)
    }

    // MARK: Bezier & easing

    /// Exact cubic-bezier y(x) by bisection on the analytic polynomial.
    private func exactBezier(_ p1x: Double, _ p1y: Double, _ p2x: Double, _ p2y: Double) -> (Double) -> Double {
        func x(_ t: Double) -> Double { 3 * (1 - t) * (1 - t) * t * p1x + 3 * (1 - t) * t * t * p2x + t * t * t }
        func y(_ t: Double) -> Double { 3 * (1 - t) * (1 - t) * t * p1y + 3 * (1 - t) * t * t * p2y + t * t * t }
        return { target in
            var lo = 0.0, hi = 1.0
            for _ in 0..<60 { let mid = (lo + hi) / 2; if x(mid) < target { lo = mid } else { hi = mid } }
            return y((lo + hi) / 2)
        }
    }

    @Test func linearBezierIsTheIdentity() {
        let linear = Bezier.linear
        #expect(linear.solve(0.0) == 0.0)
        #expect(approx(linear.solve(0.5), 0.5, 1e-3))
        #expect(linear.solve(1.0) == 1.0)
        #expect(Easing.linear.bezier == .linear)
    }

    @Test func everyPresetResolvesForEveryPlacement() {
        let curves: [Easing.Curve] = [.sine, .quad, .cubic, .quart, .quint, .expo, .back]
        for curve in curves {
            // `in` lags the identity at mid time, `out` leads it (back dips negative early).
            #expect(Easing.in(curve).bezier.solve(0.5) < 0.5)
            #expect(Easing.out(curve).bezier.solve(0.5) > 0.5)
            #expect(Easing.inOut(curve).bezier.solve(0.5) > 0.25 && Easing.inOut(curve).bezier.solve(0.5) < 0.75)
            #expect(Easing.in(curve) != Easing.out(curve))
        }
    }

    @Test func customEasingUsesTheGivenCurve() {
        let custom = Bezier(0.16, 0.73, 0.89, 0.24)
        #expect(Easing.custom(custom).bezier == custom)
        #expect(Easing.inOut(.custom(custom)).bezier == custom)
        #expect(custom.p1.x == 0.16 && custom.p2.y == 0.24)
    }

    @Test func tableSolverMatchesExactBezierEvaluation() {
        let curves = [
            (0.55, 0.055, 0.675, 0.19), (0.68, -0.55, 0.265, 1.55), (0.16, 0.73, 0.89, 0.24), (1.0, 0.0, 0.0, 1.0),
        ]
        for (a, b, c, d) in curves {
            let table = Bezier(a, b, c, d)
            let exact = exactBezier(a, b, c, d)
            for i in 1..<20 {
                let x = Double(i) / 20
                #expect(approx(table.solve(x), exact(x), 1e-3), "(\(a), \(b), \(c), \(d)) at \(x)")
            }
        }
    }

    @Test func presetCurvesApproximateEasingsNetReferenceFunctions() {
        // The Bézier presets are easings.net's approximations of the closed-form
        // functions; the approximation itself is off by up to about 0.06.
        let c1 = 1.70158, c3 = c1 + 1
        let reference: [(Easing, String, (Double) -> Double)] = [
            (.in(.quad), "quadIn", { t in t * t }),
            (.out(.quad), "quadOut", { t in 1 - (1 - t) * (1 - t) }),
            (.in(.cubic), "cubicIn", { t in t * t * t }),
            (.out(.cubic), "cubicOut", { t in 1 - pow(1 - t, 3) }),
            (.inOut(.cubic), "cubicInOut", { t in t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2 }),
            (.in(.quart), "quartIn", { t in t * t * t * t }),
            (.in(.expo), "expoIn", { t in pow(2, 10 * t - 10) }),
            (.in(.sine), "sineIn", { t in 1 - cos(t * .pi / 2) }),
            (.in(.back), "backIn", { t in c3 * t * t * t - c1 * t * t }),
        ]
        for (easing, name, function) in reference {
            for t in [0.25, 0.5, 0.75] {
                #expect(approx(easing.bezier.solve(t), function(t), 0.06), "\(name) at \(t)")
            }
        }
    }

    @Test func solveClampsTimeOutsideTheUnitInterval() {
        let curve = Easing.inOut(.back).bezier
        #expect(curve.solve(-0.5) == 0)
        #expect(curve.solve(1.5) == 1)
        // backInOut dips below 0 early and overshoots 1 late.
        #expect(curve.solve(0.1) < 0)
        #expect(curve.solve(0.9) > 1)
    }

    // MARK: Frame clock

    @Test func frameClockAdvancesByRealElapsedTime() {
        var clock = Engine.FrameClock()
        #expect(clock.frame(at: 10.000, nominalDuration: 1.0 / 60).duration == 1.0 / 60)  // first frame: nominal
        #expect(approx(clock.frame(at: 10.020, nominalDuration: 1.0 / 60).duration, 0.020))
        #expect(approx(clock.frame(at: 10.100, nominalDuration: 1.0 / 60).duration, 0.080))  // dropped frames catch up
        #expect(approx(clock.frame(at: 10.108, nominalDuration: 1.0 / 120).duration, 0.008))  // ProMotion frame
    }

    @Test func frameClockTreatsLongGapsAsOneFrame() {
        var clock = Engine.FrameClock()
        _ = clock.frame(at: 0, nominalDuration: 1.0 / 60)
        #expect(clock.frame(at: 5.0, nominalDuration: 1.0 / 60).duration == 1.0 / 60)
        clock.reset()
        #expect(clock.frame(at: 5.5, nominalDuration: 1.0 / 60).duration == 1.0 / 60)
    }

    // MARK: Pause

    @Test func pauseRunsForItsDurationThenCompletesOnce() {
        var completions = 0
        let pause = Pause(1.0, complete: { completions += 1 })
        #expect(pause.update(frame(0.25)) == .running)
        #expect(pause.update(frame(0.25)) == .running)
        #expect(pause.update(frame(0.25)) == .running)
        #expect(pause.update(frame(0.25)) == .finished)
        #expect(completions == 1)
    }

    @Test func zeroDurationPauseFinishesImmediately() {
        var completed = false
        let pause = Pause(0.0, complete: { completed = true })
        #expect(pause.update(frame(0.016)) == .finished)
        #expect(completed)
    }

    // MARK: Animation

    @Test func linearAnimationInterpolatesFrameOriginAndCompletes() {
        let view = makeView()
        var completed = false
        let a = animation(view, [.x(100)], duration: 1.0, complete: { completed = true })

        #expect(a.update(frame(0.5)) == .running)
        #expect(approx(view.frame.origin.x, 50, 0.5))
        #expect(!completed)

        #expect(a.update(frame(0.5)) == .finished)
        #expect(approx(view.frame.origin.x, 100))
        #expect(completed)
    }

    @Test func overshootingFramesClampToTheEndValue() {
        let view = makeView()
        let a = animation(view, [.y(80)], duration: 0.5)
        #expect(a.update(frame(2.0)) == .finished)
        #expect(approx(view.frame.origin.y, 80))
    }

    @Test func zeroDurationAnimationSnapsAndCompletes() {
        let view = makeView()
        var completed = false
        let a = animation(view, [.x(42), .alpha(0.5)], duration: 0.0, complete: { completed = true })
        #expect(a.update(frame(0.016)) == .finished)
        #expect(view.frame.origin.x == 42)
        #expect(approx(view.alpha, 0.5))
        #expect(completed)
    }

    @Test func everyPropertyIsAnimatable() {
        let view = makeView()
        let a = animation(
            view, [.x(30), .y(30), .width(30), .height(30), .alpha(0.3), .borderWidth(3), .cornerRadius(4)],
            duration: 1.0)
        _ = a.update(frame(1.0))
        #expect(view.frame == CGRect(x: 30, y: 30, width: 30, height: 30))
        #expect(approx(view.alpha, 0.3))
        #expect(approx(view.layer.borderWidth, 3))
        #expect(approx(view.layer.cornerRadius, 4))

        let framed = makeView()
        _ = animation(framed, [.frame(CGRect(x: 1, y: 2, width: 3, height: 4))], duration: 1.0).update(frame(1.0))
        #expect(framed.frame == CGRect(x: 1, y: 2, width: 3, height: 4))
    }

    @Test func rotationIsAnimatedInDegrees() {
        // Rotation is tested on its own: a rotated view's frame is its bounding box.
        let view = makeView()
        let a = animation(view, [.rotation(degrees: 45)], duration: 1.0)
        _ = a.update(frame(0.5))
        #expect(approx(view.rotation, 22.5, 0.1))
        _ = a.update(frame(0.5))
        #expect(approx(view.rotation, 45, 1e-4))
    }

    @Test func lastValueForARepeatedPropertyWins() {
        let view = makeView()
        _ = animation(view, [.width(20), .width(60)], duration: 1.0).update(frame(1.0))
        #expect(view.frame.size.width == 60)
    }

    @Test func easingShapesTheProgress() {
        let view = makeView()
        let a = animation(view, [.x(100)], duration: 1.0, easing: .in(.cubic))
        _ = a.update(frame(0.5))
        #expect(approx(view.frame.origin.x, 14.5, 0.5))  // cubicIn(0.5) = 0.145
    }

    @Test func animationFinishesQuietlyWhenItsViewIsGone() {
        var completed = false
        let a: Animation
        do {
            let view = makeView()
            a = animation(view, [.x(100)], duration: 1.0, complete: { completed = true })
            #expect(a.update(frame(0.1)) == .running)
        }
        #expect(a.update(frame(0.1)) == .finished)
        #expect(!completed)
    }

    @Test func reduceMotionSnapsAnimationsButKeepsPauses() {
        Engine.shared.isReduceMotionEnabled = { true }
        defer { Engine.shared.isReduceMotionEnabled = { UIAccessibility.isReduceMotionEnabled } }
        let view = makeView()
        var completed = false
        let a = animation(view, [.x(100)], duration: 1.0, complete: { completed = true })
        #expect(a.update(frame(0.016)) == .finished)
        #expect(view.frame.origin.x == 100)
        #expect(completed)
        let pause = Pause(1.0, complete: nil)
        #expect(pause.update(frame(0.5)) == .running)

        Engine.shared.respectsReduceMotion = false
        defer { Engine.shared.respectsReduceMotion = true }
        let forcedView = makeView()  // keep a strong reference: the animation holds the view weakly
        let forced = animation(forcedView, [.x(100)], duration: 1.0)
        #expect(forced.update(frame(0.5)) == .running)
    }

    // MARK: Colour

    private func rgb(_ color: UIColor?) -> UIColor.Components {
        color!.components(as: .RGB)
    }

    private func sameColour(_ a: UIColor.Components, _ b: UIColor.Components, _ tolerance: CGFloat) -> Bool {
        approx(a.c1, b.c1, tolerance) && approx(a.c2, b.c2, tolerance) && approx(a.c3, b.c3, tolerance)
    }

    @Test func backgroundReachesTargetInEveryColourSpace() {
        let from = UIColor(red: 1.00, green: 0.44, blue: 0.75, alpha: 1.00)
        let to = UIColor(red: 0.00, green: 1.00, blue: 1.00, alpha: 1.00)
        for mode in [ColorInterpolation.rgb, .hsb, .lch] {
            let view = makeView()
            view.backgroundColor = from
            let a = animation(view, [.background(to, interpolation: mode)], duration: 1.0)
            _ = a.update(frame(0.5))
            let mid = rgb(view.backgroundColor)
            #expect(
                !sameColour(mid, rgb(from), 0.05) && !sameColour(mid, rgb(to), 0.05),
                "\(mode): half way must be neither endpoint")
            _ = a.update(frame(0.5))
            #expect(sameColour(rgb(view.backgroundColor), rgb(to), 0.01), "\(mode)")
        }
    }

    @Test func lchIsTheDefaultAndAvoidsTheGreyMidpoint() {
        let view = makeView()
        view.backgroundColor = .red
        let a = animation(view, [.background(.blue)], duration: 1.0)
        _ = a.update(frame(0.5))
        let mid = rgb(view.backgroundColor)
        // Straight RGB gives (0.5, 0, 0.5); the LCH path is brighter and purpler.
        #expect(mid.c1 + mid.c2 + mid.c3 > 1.2)
    }

    @Test func overshootingEasingDoesNotBreakColourInterpolation() {
        let view = makeView()
        view.backgroundColor = .red
        let a = animation(view, [.background(.blue)], duration: 1.0, easing: .inOut(.back))
        for _ in 0..<10 { _ = a.update(frame(0.1)) }
        #expect(sameColour(rgb(view.backgroundColor), rgb(.blue), 0.01))
    }

    @Test func borderColourAnimatesTheLayer() {
        let view = makeView()
        view.layer.borderColor = UIColor.black.cgColor
        _ = animation(view, [.borderColor(.white, interpolation: .rgb)], duration: 1.0).update(frame(1.0))
        #expect(sameColour(rgb(UIColor(cgColor: view.layer.borderColor!)), rgb(.white), 0.01))
    }

    @Test func hsbHueTakesTheShorterArc() {
        // Hue 0.95 to 0.05 must pass through red (hue 0), not through cyan.
        let view = makeView()
        view.backgroundColor = UIColor(hue: 0.95, saturation: 1, brightness: 1, alpha: 1)
        let a = animation(
            view, [.background(UIColor(hue: 0.05, saturation: 1, brightness: 1, alpha: 1), interpolation: .hsb)],
            duration: 1.0)
        _ = a.update(frame(0.5))
        #expect(sameColour(rgb(view.backgroundColor), rgb(.red), 0.02))
    }

    // MARK: Sequence & Group

    @Test func sequenceRunsChildrenInOrder() {
        let view = makeView()
        let sequence = Sequence([
            .pause(1.0, nil),
            .animation(ViewRef(view), [.x(100)], 1.0, nil, nil),
        ])

        #expect(sequence.update(frame(0.5)) == .running)
        #expect(view.frame.origin.x == 0, "animation must not start during the pause")
        #expect(sequence.update(frame(0.5)) == .running)  // pause ends
        #expect(sequence.update(frame(0.5)) == .running)  // animation half way
        #expect(approx(view.frame.origin.x, 50, 0.5))
        #expect(sequence.update(frame(0.5)) == .finished)
        #expect(approx(view.frame.origin.x, 100))
    }

    @Test func sequenceFiresItsOwnCompletionExactlyOnce() {
        var completions = 0
        let sequence = Sequence([.pause(0.5, nil), .pause(0.5, nil)], complete: { completions += 1 })
        #expect(sequence.update(frame(0.6)) == .running)
        #expect(completions == 0)
        #expect(sequence.update(frame(0.6)) == .finished)
        #expect(completions == 1)
    }

    @Test func pausedSequenceDoesNotAdvance() {
        let view = makeView()
        let sequence = Sequence([.animation(ViewRef(view), [.x(100)], 1.0, nil, nil)])
        _ = sequence.update(frame(0.5))
        sequence.isPaused = true
        #expect(sequence.update(frame(0.5)) == .running)
        #expect(approx(view.frame.origin.x, 50, 0.5))
        sequence.isPaused = false
        #expect(sequence.update(frame(0.5)) == .finished)
        #expect(approx(view.frame.origin.x, 100))
    }

    @Test func groupFinishesWhenTheLongestChildFinishes() {
        let a = makeView(), b = makeView()
        var completed = false
        let group = Group(
            [
                .animation(ViewRef(a), [.x(100)], 0.5, nil, nil),
                .animation(ViewRef(b), [.x(100)], 1.0, nil, nil),
            ], complete: { completed = true })

        #expect(group.update(frame(0.5)) == .running)
        #expect(approx(a.frame.origin.x, 100))
        #expect(approx(b.frame.origin.x, 50, 0.5))
        #expect(!completed)

        #expect(group.update(frame(0.5)) == .finished)
        #expect(approx(b.frame.origin.x, 100))
        #expect(completed)
    }

    // MARK: Kinieta chain building

    private func descriptions(_ k: Kinieta) -> [String] {
        k.mainSequence.types.map { $0.description }
    }

    @Test func animateAppendsAnAnimation() {
        let k = Kinieta(for: makeView()).animate(.x(1), .alpha(0), duration: 1)
        #expect(descriptions(k) == ["Animation (x alpha)"])
        k.cancel()
    }

    @Test func delayWrapsTheLastActionInASequenceWithAPause() {
        let k = Kinieta(for: makeView()).animate(.x(1), duration: 1).delay(0.5)
        defer { k.cancel() }
        #expect(descriptions(k) == ["Sequence (2)"])
        guard case .sequence(let inner, _)? = k.mainSequence.types.first else {
            Issue.record("expected a Sequence"); return
        }
        #expect(inner.map { $0.description } == ["Pause (0.5)", "Animation (x)"])
    }

    @Test func parallelGroupsAllUngroupedActions() {
        let k = Kinieta(for: makeView())
            .animate(.x(1), duration: 1)
            .animate(.alpha(0), duration: 1)
            .parallel()
        defer { k.cancel() }
        #expect(descriptions(k) == ["Group (2)"])
    }

    @Test func thenSealsPrecedingActionsInOrder() {
        let k = Kinieta(for: makeView())
            .animate(.x(1), duration: 1)
            .wait(1)
            .then
            .animate(.x(2), duration: 1)
            .animate(.alpha(0), duration: 1)
            .parallel()
        defer { k.cancel() }
        #expect(descriptions(k) == ["Group (1)", "Group (2)"])
        guard case .group(let sealed, _)? = k.mainSequence.types.first,
            case .sequence(let steps, _)? = sealed.first
        else {
            Issue.record("expected a Group holding a Sequence"); return
        }
        #expect(steps.map { $0.description } == ["Animation (x)", "Pause (1.0)"], "then must keep the original order")
    }

    @Test func repeatAppendsCopiesOfTheWholeChain() {
        let k = Kinieta(for: makeView())
            .animate(.x(1), duration: 1)
            .wait(1)
            .repeat(times: 2)
        defer { k.cancel() }
        #expect(
            descriptions(k) == [
                "Animation (x)", "Pause (1.0)", "Animation (x)", "Pause (1.0)", "Animation (x)", "Pause (1.0)",
            ])
    }

    @Test func easingAttachesToTheLastAnimationOnly() {
        let k = Kinieta(for: makeView()).animate(.x(1), duration: 1).easeInOut(.back).wait(1).easeIn()
        defer { k.cancel() }
        guard case .animation(_, _, _, let bezier?, _)? = k.mainSequence.types.first else {
            Issue.record("no easing attached"); return
        }
        #expect(bezier == Easing.inOut(.back).bezier)
        #expect(descriptions(k) == ["Animation (x)", "Pause (1.0)"])
    }

    @Test func onCompleteAttachesToTheLastAction() {
        let k = Kinieta(for: makeView()).animate(.x(1), duration: 1).wait(1).onComplete {}
        defer { k.cancel() }
        guard case .pause(_, let block)? = k.mainSequence.types.last else {
            Issue.record("expected a Pause"); return
        }
        #expect(block != nil)
    }

    // MARK: End to end through the display link

    @Test(.timeLimit(.minutes(1)))
    func timelineRunsToCompletionAndCanBeAwaited() async {
        let view = makeView()
        var completed = false
        let handle = view.animate(.x(100), duration: 0.2).onComplete { completed = true }
        #expect(handle.isRunning)
        await handle.finished()
        #expect(handle.state == .finished)
        #expect(completed)
        #expect(approx(view.frame.origin.x, 100))
        await handle.finished()  // already finished: returns immediately
    }

    @Test(.timeLimit(.minutes(1)))
    func cancelStopsTheTimelineWhereItIs() async {
        let view = makeView()
        var completed = false
        let handle = view.animate(.x(100), duration: 10).onComplete { completed = true }
        try? await Task.sleep(for: .milliseconds(150))
        handle.cancel()
        let x = view.frame.origin.x
        #expect(x > 0 && x < 100)
        #expect(handle.state == .cancelled)
        await handle.finished()
        try? await Task.sleep(for: .milliseconds(100))
        #expect(view.frame.origin.x == x)
        #expect(!completed)
    }

    @Test(.timeLimit(.minutes(1)))
    func pauseAndResumeHoldTheTimeline() async {
        let view = makeView()
        let handle = view.animate(.x(100), duration: 0.3)
        try? await Task.sleep(for: .milliseconds(100))
        handle.pause()
        #expect(handle.isPaused)
        let held = view.frame.origin.x
        try? await Task.sleep(for: .milliseconds(150))
        #expect(view.frame.origin.x == held)
        handle.resume()
        await handle.finished()
        #expect(approx(view.frame.origin.x, 100))
    }

    @Test(.timeLimit(.minutes(1)))
    func groupOfHandlesCompletesOnceWhenTheLastFinishes() async {
        let a = makeView(), b = makeView()
        var completions = 0
        let group = Kinieta.group(a.animate(.x(100), duration: 0.1), b.animate(.y(100), duration: 0.3)) {
            completions += 1
        }
        await group.finished()
        #expect(completions == 1)
        #expect(approx(a.frame.origin.x, 100))
        #expect(approx(b.frame.origin.y, 100))
    }

    @Test(.timeLimit(.minutes(1)))
    func timelineFinishesOnItsOwnWhenTheViewIsReleased() async {
        var view: UIView? = makeView()
        let handle = view!.animate(.x(100), duration: 10)
        #expect(handle.view != nil)
        view = nil
        await handle.finished()
        #expect(handle.view == nil)
        #expect(handle.state == .finished)
    }
}

func approx<T: BinaryFloatingPoint>(_ a: T, _ b: T, _ tolerance: T = 1e-6) -> Bool {
    abs(a - b) <= tolerance
}
