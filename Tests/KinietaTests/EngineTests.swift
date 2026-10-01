#if canImport(UIKit)
import Testing
import UIKit

@testable import Kinieta

/// Engine tests. Actions are driven with synthetic `Engine.Frame` values so no
/// display link is involved.
///
/// The end-to-end tests at the bottom go through the public `Kinieta` handle
/// API. They install a `ManualFrameDriver` on `Engine.shared` and step frames
/// by hand, so they never depend on wall-clock timing:
///
///     let frames = ManualFrameDriver.install()
///     defer { frames.uninstall() }
///     let handle = view.animate(.x(100), duration: 1)
///     frames.step(0.25)  // x == 25
///
/// One smoke test still runs on the real `CADisplayLink`.
///
/// Serialized, and alone among the other suites that use `Engine.shared`, because
/// every test shares it and its frame driver.
@Suite(.serialized, .usesSharedEngine)
@MainActor
struct EngineTests {

    // Tests must not depend on the host's accessibility settings: on Mac Catalyst,
    // UIAccessibility reads the Mac's Reduce Motion switch, which some CI runners have on.
    init() {
        Engine.shared.isReduceMotionEnabled = { false }
    }

    private func frame(_ dt: TimeInterval) -> Engine.Frame {
        Engine.Frame(dt)
    }

    private func makeView() -> UIView {
        UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
    }

    private func animation(
        _ view: UIView, _ properties: [Property], duration: TimeInterval,
        easing: Easing? = nil, completion: Kinieta.Completion? = nil
    ) -> PropertyAnimation {
        let spec = AnimationSpec(view, properties, duration: duration, easing: easing?.bezier, completion: completion)
        return PropertyAnimation(spec)
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
        #expect(linear.progress(at: 0.0) == 0.0)
        #expect(approx(linear.progress(at: 0.5), 0.5, 1e-3))
        #expect(linear.progress(at: 1.0) == 1.0)
        #expect(Easing.linear.bezier == .linear)
    }

    @Test func everyPresetResolvesForEveryPlacement() {
        let curves: [Easing.Curve] = [.sine, .quad, .cubic, .quart, .quint, .expo, .back]
        for curve in curves {
            // `in` lags the identity at mid time, `out` leads it (back dips negative early).
            #expect(Easing.in(curve).bezier.progress(at: 0.5) < 0.5)
            #expect(Easing.out(curve).bezier.progress(at: 0.5) > 0.5)
            #expect((0.25...0.75).contains(Easing.inOut(curve).bezier.progress(at: 0.5)))
            #expect(Easing.in(curve) != Easing.out(curve))
        }
    }

    @Test func everyPresetBezierIsDistinct() {
        let curves: [(Easing.Curve, String)] = [
            (.sine, "sine"), (.quad, "quad"), (.cubic, "cubic"), (.quart, "quart"),
            (.quint, "quint"), (.expo, "expo"), (.back, "back"),
        ]
        let placements: [(Easing.Placement, String)] = [(.in, "in"), (.out, "out"), (.inOut, "inOut")]
        let presets = curves.flatMap { curve, curveName in
            placements.map { placement, placementName in
                ("\(placementName)(.\(curveName))", Easing.resolve(curve, placement))
            }
        }
        #expect(presets.count == 21)
        for i in presets.indices {
            for j in presets.indices where j > i {
                let (a, b) = (presets[i].1, presets[j].1)
                let same = a.p1 == b.p1 && a.p2 == b.p2
                #expect(!same, "\(presets[i].0) and \(presets[j].0) share the control points \(a.p1), \(a.p2)")
            }
        }
    }

    @Test func customEasingUsesTheGivenCurve() {
        let custom = Bezier(0.16, 0.73, 0.89, 0.24)
        #expect(Easing.custom(custom).bezier == custom)
        #expect(Easing.inOut(.deprecatedCustom(custom)).bezier == custom)
        #expect(Easing.in(.deprecatedCustom(custom)).bezier == custom)
        #expect(custom.p1.x == 0.16 && custom.p2.y == 0.24)
    }

    @Test func deprecatedBezierSpellingsStillWork() {
        let curve = Bezier(0.16, 0.73, 0.89, 0.24)
        for i in 0...20 {
            let x = Double(i) / 20
            #expect(curve.deprecatedSolve(x) == curve.progress(at: x))
        }
        #expect(Bezier.Point.deprecatedInit(0.25, -0.5) == Bezier.Point(x: 0.25, y: -0.5))
        #expect(Bezier.Point(x: 0.25, y: -0.5).description == "(x: 0.25, y: -0.5)")
        #expect(curve.p0 == Bezier.Point(x: 0, y: 0) && curve.p3 == Bezier.Point(x: 1, y: 1))
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
                #expect(approx(table.progress(at: x), exact(x), 1e-3), "(\(a), \(b), \(c), \(d)) at \(x)")
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
            (.inOut(.sine), "sineInOut", { t in 0.5 - cos(.pi * t) / 2 }),
            (.inOut(.quad), "quadInOut", { t in t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2 }),
            (.in(.back), "backIn", { t in c3 * t * t * t - c1 * t * t }),
        ]
        for (easing, name, function) in reference {
            for t in [0.25, 0.5, 0.75] {
                #expect(approx(easing.bezier.progress(at: t), function(t), 0.06), "\(name) at \(t)")
            }
        }
    }

    @Test func progressClampsTimeOutsideTheUnitInterval() {
        let curve = Easing.inOut(.back).bezier
        #expect(curve.progress(at: -0.5) == 0)
        #expect(curve.progress(at: 1.5) == 1)
        // backInOut dips below 0 early and overshoots 1 late.
        #expect(curve.progress(at: 0.1) < 0)
        #expect(curve.progress(at: 0.9) > 1)
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

    // MARK: Frame remainder

    @Test func sequenceHandsTheUnusedPartOfAFrameToTheNextAction() {
        // Two half-second pauses driven by 0.3 s frames end after 1.2 s, not 1.5 s.
        let pauses = SequenceAction([.pause(0.5), .pause(0.5)])
        #expect(pauses.update(frame(0.3)) == .running)
        #expect(pauses.update(frame(0.3)) == .running)  // first ends here, second gets 0.1 s
        #expect(pauses.update(frame(0.3)) == .running)
        guard case .finished(let overshoot) = pauses.update(frame(0.3)) else { Issue.record("not finished"); return }
        #expect(approx(overshoot, 0.2, 1e-9))

        // An animation that starts mid-frame has already progressed by the remainder.
        let view = makeView()
        let mixed = SequenceAction([.pause(0.5), .animation(AnimationSpec(view, [.x(100)], duration: 1.0))])
        #expect(mixed.update(frame(0.75)) == .running)
        #expect(approx(view.frame.origin.x, 25, 0.5))
    }

    @Test func bezierClampsControlPointTimeToTheUnitInterval() {
        let curve = Bezier(-1, 0, 2, 1)
        #expect(curve.p1.x == 0 && curve.p2.x == 1)
        var previous = 0.0
        for i in 1...20 {
            let y = curve.progress(at: Double(i) / 20)
            #expect(y >= previous && y <= 1)
            previous = y
        }
    }

    // MARK: Pause

    @Test func pauseRunsForItsDurationThenCompletesOnce() {
        var completions = 0
        let pause = PauseAction(1.0, completion: { completions += 1 })
        #expect(pause.update(frame(0.25)) == .running)
        #expect(pause.update(frame(0.25)) == .running)
        #expect(pause.update(frame(0.25)) == .running)
        #expect(pause.update(frame(0.25)).isFinished)
        #expect(completions == 1)
    }

    @Test func zeroDurationPauseFinishesImmediately() {
        var completed = false
        let pause = PauseAction(0.0, completion: { completed = true })
        #expect(pause.update(frame(0.016)).isFinished)
        #expect(completed)
    }

    @Test func pauseNeverHandsOnMoreThanTheFrame() {
        #expect(PauseAction(-5, completion: nil).update(frame(0.1)) == .finished(overshoot: 0.1))
    }

    // MARK: Animation

    @Test func linearAnimationInterpolatesFrameOriginAndCompletes() {
        let view = makeView()
        var completed = false
        let a = animation(view, [.x(100)], duration: 1.0, completion: { completed = true })

        #expect(a.update(frame(0.5)) == .running)
        #expect(approx(view.frame.origin.x, 50, 0.5))
        #expect(!completed)

        #expect(a.update(frame(0.5)).isFinished)
        #expect(approx(view.frame.origin.x, 100))
        #expect(completed)
    }

    @Test func overshootingFramesClampToTheEndValue() {
        let view = makeView()
        let a = animation(view, [.y(80)], duration: 0.5)
        #expect(a.update(frame(2.0)).isFinished)
        #expect(approx(view.frame.origin.y, 80))
    }

    @Test func zeroDurationAnimationSnapsAndCompletes() {
        let view = makeView()
        var completed = false
        let a = animation(view, [.x(42), .alpha(0.5)], duration: 0.0, completion: { completed = true })
        #expect(a.update(frame(0.016)).isFinished)
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

    @Test func rotationContinuesFromTheUnwrappedAngle() {
        // 270 reads back as -90 from the transform; the next animation must still turn 90°, not 450°.
        let view = makeView()
        _ = animation(view, [.rotation(degrees: 270)], duration: 1.0).update(frame(1.0))
        #expect(approx(view.rotation, 270, 1e-4))
        let a = animation(view, [.rotation(degrees: 360)], duration: 1.0)
        _ = a.update(frame(0.5))
        #expect(approx(view.rotation, 315, 1e-4))
        _ = a.update(frame(0.5))
        #expect(approx(view.rotation, 360, 1e-4))
    }

    @Test func multiTurnRotationCanBeContinued() {
        let view = makeView()
        _ = animation(view, [.rotation(degrees: 720)], duration: 1.0).update(frame(1.0))
        let a = animation(view, [.rotation(degrees: 810)], duration: 1.0)
        _ = a.update(frame(0.5))
        #expect(approx(view.rotation, 765, 1e-4))
        _ = a.update(frame(0.5))
        #expect(approx(view.rotation, 810, 1e-4))
        #expect(approx(atan2(view.transform.b, view.transform.a).radiansToDegrees, 90, 1e-4))
    }

    @Test func rotationKeepsScaleAndTranslation() {
        let view = makeView()
        view.transform = CGAffineTransform(translationX: 5, y: 7).scaledBy(x: 2, y: 3)
        let a = animation(view, [.rotation(degrees: 90)], duration: 1.0)
        for _ in 0..<10 { _ = a.update(frame(0.1)) }
        // Scaled in the view's own axes, then rotated.
        let expected = CGAffineTransform(scaleX: 2, y: 3).concatenating(CGAffineTransform(rotationAngle: .pi / 2))
        let t = view.transform
        #expect(approx(t.a, expected.a) && approx(t.b, expected.b))
        #expect(approx(t.c, expected.c) && approx(t.d, expected.d))
        #expect(t.tx == 5 && t.ty == 7)
        #expect(approx(view.rotation, 90))

        // Back to zero leaves exactly the scale and translation it started with.
        _ = animation(view, [.rotation(degrees: 0)], duration: 1.0).update(frame(1.0))
        #expect(approx(view.transform.a, 2) && approx(view.transform.d, 3))
        #expect(approx(view.transform.b, 0) && approx(view.transform.c, 0))
        #expect(view.transform.tx == 5 && view.transform.ty == 7)
    }

    @Test func rotationRestartsFromTheTransformWhenItIsChangedElsewhere() {
        // The demo resets its squares with `transform = .identity` between runs.
        let view = makeView()
        _ = animation(view, [.rotation(degrees: 540)], duration: 1.0).update(frame(1.0))
        view.transform = .identity
        #expect(view.rotation == 0)
        let a = animation(view, [.rotation(degrees: 180)], duration: 1.0)
        _ = a.update(frame(0.5))
        #expect(approx(view.rotation, 90, 1e-4))
    }

    @Test func overshootingEasingNeverProducesNegativeSizes() {
        let view = makeView()
        view.layer.borderWidth = 2
        view.layer.cornerRadius = 3
        let a = animation(
            view, [.width(0), .height(0), .borderWidth(0), .cornerRadius(0)], duration: 1.0, easing: .inOut(.back))
        for _ in 0..<10 {
            _ = a.update(frame(0.1))
            #expect(view.bounds.width >= 0 && view.bounds.height >= 0)
            #expect(view.layer.borderWidth >= 0 && view.layer.cornerRadius >= 0)
        }
        #expect(view.bounds.size == .zero)
    }

    @Test func frameOnARotatedViewMovesItsCentreAndBounds() {
        // A rotated view's `frame` is its bounding box; the target is the rect before rotation.
        let view = makeView()
        view.rotation = 45
        let a = animation(view, [.frame(CGRect(x: 20, y: 30, width: 40, height: 60))], duration: 1.0)
        _ = a.update(frame(0.5))
        #expect(approx(view.center.x, 22.5) && approx(view.center.y, 32.5))
        #expect(approx(view.bounds.width, 25) && approx(view.bounds.height, 35))
        _ = a.update(frame(0.5))
        #expect(approx(view.center.x, 40) && approx(view.center.y, 60))
        #expect(view.bounds.size == CGSize(width: 40, height: 60))
        #expect(approx(view.rotation, 45))
    }

    @Test func overshootingEasingNeverProducesANegativeFrame() {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let target = CGRect(x: 50, y: 50, width: 2, height: 2)
        let a = animation(view, [.frame(target)], duration: 1.0, easing: .inOut(.back))
        var clamped = false
        for _ in 0..<40 {
            _ = a.update(frame(0.025))
            #expect(view.bounds.width >= 0 && view.bounds.height >= 0)
            if view.bounds.size == .zero {
                // Past the end, the corner keeps going instead of jumping back to a standardised origin.
                clamped = true
                #expect(view.frame.origin.x > 50 && view.frame.origin.y > 50)
            }
        }
        #expect(clamped)
        #expect(view.frame == target)
    }

    @Test func frameTargetWithANegativeSizeIsStandardised() {
        let view = makeView()
        _ = animation(view, [.frame(CGRect(x: 30, y: 40, width: -20, height: -10))], duration: 1.0).update(frame(1.0))
        #expect(view.frame == CGRect(x: 10, y: 30, width: 20, height: 10))
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
        let a: PropertyAnimation
        do {
            let view = makeView()
            a = animation(view, [.x(100)], duration: 1.0, completion: { completed = true })
            #expect(a.update(frame(0.1)) == .running)
        }
        #expect(a.update(frame(0.1)).isFinished)
        #expect(!completed)
    }

    @Test func reduceMotionSnapsAnimationsButKeepsPauses() {
        Engine.shared.isReduceMotionEnabled = { true }
        defer { Engine.shared.isReduceMotionEnabled = { false } }
        let view = makeView()
        var completed = false
        let a = animation(view, [.x(100)], duration: 1.0, completion: { completed = true })
        #expect(a.update(frame(0.016)).isFinished)
        #expect(view.frame.origin.x == 100)
        #expect(completed)
        let pause = PauseAction(1.0, completion: nil)
        #expect(pause.update(frame(0.5)) == .running)

        Engine.shared.respectsReduceMotion = false
        defer { Engine.shared.respectsReduceMotion = true }
        let forcedView = makeView()  // keep a strong reference: the animation holds the view weakly
        let forced = animation(forcedView, [.x(100)], duration: 1.0)
        #expect(forced.update(frame(0.5)) == .running)
    }

    @Test func reduceMotionSnapsMotionButKeepsFadesAndColours() {
        Engine.shared.isReduceMotionEnabled = { true }
        defer { Engine.shared.isReduceMotionEnabled = { false } }
        #expect(Engine.shared.reduceMotionBehavior == .snapMotion)
        let view = makeView()
        view.backgroundColor = .black
        var completed = false
        let a = animation(
            view, [.x(100), .alpha(0), .background(.white, interpolation: .rgb)], duration: 1.0,
            completion: { completed = true })

        #expect(a.update(frame(0.25)) == .running)
        #expect(view.frame.origin.x == 100)
        #expect(approx(view.alpha, 0.75, 1e-6))
        #expect(approx(rgb(view.backgroundColor).red, 0.25, 0.01))
        #expect(!completed)

        #expect(a.update(frame(0.75)) == .finished(overshoot: 0))
        #expect(view.frame.origin.x == 100)
        #expect(view.alpha == 0)
        #expect(completed)
    }

    @Test func snapAllUnderReduceMotionKeepsTheOneZeroBehaviour() {
        Engine.shared.isReduceMotionEnabled = { true }
        Engine.shared.reduceMotionBehavior = .snapAll
        defer {
            Engine.shared.isReduceMotionEnabled = { false }
            Engine.shared.reduceMotionBehavior = .snapMotion
        }
        let view = makeView()
        var completed = false
        let a = animation(view, [.x(100), .alpha(0)], duration: 1.0, completion: { completed = true })
        #expect(a.update(frame(0.016)).isFinished)
        #expect(view.frame.origin.x == 100)
        #expect(view.alpha == 0)
        #expect(completed)
    }

    @Test func reduceMotionBehaviourIsIgnoredWhenReduceMotionIsOff() {
        Engine.shared.isReduceMotionEnabled = { false }
        Engine.shared.reduceMotionBehavior = .snapAll
        defer {
            Engine.shared.isReduceMotionEnabled = { false }
            Engine.shared.reduceMotionBehavior = .snapMotion
        }
        let view = makeView()
        let a = animation(view, [.x(100), .alpha(0)], duration: 1.0)
        #expect(a.update(frame(0.5)) == .running)
        #expect(approx(view.frame.origin.x, 50, 1e-6))
        #expect(approx(view.alpha, 0.5, 1e-6))
    }

    @Test func onlyPositionSizeAndRotationCountAsMotion() {
        let motion: [Property] = [.x(1), .y(1), .width(1), .height(1), .frame(.zero), .rotation(degrees: 1)]
        let still: [Property] = [.alpha(1), .background(.red), .borderColor(.red), .borderWidth(1), .cornerRadius(1)]
        let motionKeys = motion.map(\.isMotion)
        let stillKeys = still.map(\.isMotion)
        #expect(motionKeys == Array(repeating: true, count: motion.count))
        #expect(stillKeys == Array(repeating: false, count: still.count))
    }

    @Test func reduceMotionKeepsTheTimingOfATimelineThatFades() {
        Engine.shared.isReduceMotionEnabled = { true }
        defer { Engine.shared.isReduceMotionEnabled = { false } }
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.animate(.x(100), duration: 1.0).animate(.alpha(0), duration: 1.0)
        frames.step(0.016)
        #expect(view.frame.origin.x == 100)
        frames.step(0.5)
        #expect(approx(view.alpha, 0.5, 0.02))
        frames.step(0.5)
        #expect(view.alpha == 0)
        #expect(handle.state == .finished)
    }

    // MARK: Colour

    private func rgb(_ color: UIColor?) -> ColorMath.RGB {
        ColorMath.extractComponents(of: color!)!
    }

    private func sameColour(_ a: ColorMath.RGB, _ b: ColorMath.RGB, _ tolerance: CGFloat) -> Bool {
        approx(a.red, b.red, tolerance) && approx(a.green, b.green, tolerance) && approx(a.blue, b.blue, tolerance)
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
        #expect(mid.red + mid.green + mid.blue > 1.2)
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

    @Test func dynamicColourTargetSurvivesTheAnimation() {
        let view = makeView()
        view.backgroundColor = .red
        let adaptive = UIColor { $0.userInterfaceStyle == .dark ? .white : .black }
        _ = animation(view, [.background(adaptive)], duration: 1.0).update(frame(1.0))
        let light = view.backgroundColor!.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let dark = view.backgroundColor!.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        #expect(sameColour(rgb(light), rgb(.black), 1e-6))
        #expect(sameColour(rgb(dark), rgb(.white), 1e-6))
    }

    @Test func hsbFromGreyDoesNotSweepTheHueWheel() {
        let view = makeView()
        view.backgroundColor = .gray
        let a = animation(view, [.background(.blue, interpolation: .hsb)], duration: 1.0)
        _ = a.update(frame(0.5))
        #expect(approx(rgb(view.backgroundColor).hsb.hue, 240, 1))  // blue's hue, not a sweep from 0
    }

    @Test func fadingFromClearKeepsTheTargetColour() {
        let view = makeView()
        view.backgroundColor = .clear
        let a = animation(view, [.background(.white, interpolation: .rgb)], duration: 1.0)
        _ = a.update(frame(0.5))
        let mid = rgb(view.backgroundColor)
        #expect(approx(mid.red, 1, 1e-6) && approx(mid.green, 1, 1e-6) && approx(mid.blue, 1, 1e-6))
        #expect(approx(mid.alpha, 0.5, 1e-6))
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

    private var pattern: UIColor {
        UIColor(patternImage: UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { _ in })
    }

    @Test func patternColourTargetSnapsInsteadOfFading() {
        let view = makeView()
        view.backgroundColor = .red
        let target = pattern
        let a = animation(view, [.background(target)], duration: 1.0)
        _ = a.update(frame(0.25))
        #expect(view.backgroundColor === target)
        _ = a.update(frame(1.0))
        #expect(view.backgroundColor === target)
    }

    @Test func patternColourSourceSnapsInsteadOfFading() {
        // Read as transparent, the blue would fade in from alpha 0.
        let view = makeView()
        view.backgroundColor = pattern
        _ = animation(view, [.background(.blue)], duration: 1.0).update(frame(0.25))
        #expect(view.backgroundColor == .blue)
    }

    @Test func cmykBorderColourBlendsInsteadOfFading() {
        let view = makeView()
        let cmykRed = CGColor(colorSpace: CGColorSpaceCreateDeviceCMYK(), components: [0, 1, 1, 0, 1])!
        view.layer.borderColor = cmykRed
        _ = animation(view, [.borderColor(.blue, interpolation: .rgb)], duration: 1.0).update(frame(0.5))
        let mid = rgb(UIColor(cgColor: view.layer.borderColor!))
        #expect(approx(mid.alpha, 1, 1e-6), "\(mid)")
        #expect(mid.red > 0.3 && mid.blue > 0.3, "half way from red to blue: \(mid)")
    }

    /// The LCH hue of `view`'s background, in degrees away from `hue`.
    private func hueDistance(_ view: UIView, from hue: CGFloat) -> CGFloat {
        let delta = abs(rgb(view.backgroundColor).lch.hue - hue).truncatingRemainder(dividingBy: 360)
        return min(delta, 360 - delta)
    }

    @Test(arguments: [
        UIColor.systemGray,
        UIColor(red: 0.52, green: 0.50, blue: 0.47, alpha: 1),  // warm: its hue is opposite blue's
    ])
    func lchFromANearGreyHeadsStraightForTheTargetHue(_ grey: UIColor) {
        let light = UITraitCollection(userInterfaceStyle: .light)
        let blue = UIColor.systemBlue.resolvedColor(with: light)
        let blueHue = rgb(blue).lch.hue
        let view = makeView()
        view.overrideUserInterfaceStyle = .light
        view.backgroundColor = grey.resolvedColor(with: light)
        let a = animation(view, [.background(blue)], duration: 1.0)
        for _ in 0..<3 {
            _ = a.update(frame(0.25))
            #expect(hueDistance(view, from: blueHue) < 25, "\(rgb(view.backgroundColor).lch)")
        }
        #expect(hueDistance(view, from: blueHue) < 10, "three quarters of the way")
    }

    @Test func lchBetweenTwoColoursIsUnweighted() {
        // Both well above the neutral chroma: hue moves exactly with progress.
        let from = ColorMath.LCH(lightness: 50, chroma: 40, hue: 0, alpha: 1)
        let to = ColorMath.LCH(lightness: 50, chroma: 90, hue: 100, alpha: 1)
        #expect(approx(from.lerp(to, 0.5).hue, 50, 1e-9))
    }

    // MARK: Sequence & Group

    @Test func sequenceRunsChildrenInOrder() {
        let view = makeView()
        let sequence = SequenceAction([
            .pause(1.0),
            .animation(AnimationSpec(view, [.x(100)], duration: 1.0)),
        ])

        #expect(sequence.update(frame(0.5)) == .running)
        #expect(view.frame.origin.x == 0, "animation must not start during the pause")
        #expect(sequence.update(frame(0.5)) == .running)  // pause ends
        #expect(sequence.update(frame(0.5)) == .running)  // animation half way
        #expect(approx(view.frame.origin.x, 50, 0.5))
        #expect(sequence.update(frame(0.5)).isFinished)
        #expect(approx(view.frame.origin.x, 100))
    }

    @Test func sequenceFiresItsOwnCompletionExactlyOnce() {
        var completions = 0
        let sequence = SequenceAction([.pause(0.5), .pause(0.5)], completion: { completions += 1 })
        #expect(sequence.update(frame(0.6)) == .running)
        #expect(completions == 0)
        #expect(sequence.update(frame(0.6)).isFinished)
        #expect(completions == 1)
    }

    @Test func pausedSequenceDoesNotAdvance() {
        let view = makeView()
        let sequence = SequenceAction([.animation(AnimationSpec(view, [.x(100)], duration: 1.0))])
        _ = sequence.update(frame(0.5))
        sequence.isPaused = true
        #expect(sequence.update(frame(0.5)) == .running)
        #expect(approx(view.frame.origin.x, 50, 0.5))
        sequence.isPaused = false
        #expect(sequence.update(frame(0.5)).isFinished)
        #expect(approx(view.frame.origin.x, 100))
    }

    @Test func groupFinishesWhenTheLongestChildFinishes() {
        let a = makeView(), b = makeView()
        var completed = false
        let group = GroupAction(
            pending: [
                .animation(AnimationSpec(a, [.x(100)], duration: 0.5)),
                .animation(AnimationSpec(b, [.x(100)], duration: 1.0)),
            ], completion: { completed = true })

        #expect(group.update(frame(0.5)) == .running)
        #expect(approx(a.frame.origin.x, 100))
        #expect(approx(b.frame.origin.x, 50, 0.5))
        #expect(!completed)

        #expect(group.update(frame(0.5)).isFinished)
        #expect(approx(b.frame.origin.x, 100))
        #expect(completed)
    }

    // MARK: Kinieta chain building

    private func descriptions(_ k: Kinieta) -> [String] {
        k.timeline.map { $0.description }
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
        guard case .sequence(let inner, _)? = k.timeline.first else {
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
            .then()
            .animate(.x(2), duration: 1)
            .animate(.alpha(0), duration: 1)
            .parallel()
        defer { k.cancel() }
        #expect(descriptions(k) == ["Group (1)", "Group (2)"])
        guard case .group(let sealed, _)? = k.timeline.first,
            case .sequence(let steps, _)? = sealed.first
        else {
            Issue.record("expected a Group holding a Sequence"); return
        }
        #expect(steps.map { $0.description } == ["Animation (x)", "Pause (1.0)"], "then must keep the original order")
    }

    @Test func deprecatedThenPropertyStillSeals() {
        let k = Kinieta(for: makeView()).animate(.x(1), duration: 1).wait(1)
        defer { k.cancel() }
        let calls = ignoredCalls { _ = k.deprecatedThen.deprecatedThen }
        #expect(descriptions(k) == ["Group (1)"])
        #expect(calls.count == 1 && calls.first?.site == nil)
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
        guard case .animation(let spec)? = k.timeline.first, let bezier = spec.easing else {
            Issue.record("no easing attached"); return
        }
        #expect(bezier == Easing.inOut(.back).bezier)
        #expect(descriptions(k) == ["Animation (x)", "Pause (1.0)"])
    }

    @Test func easingReachesAnAnimationWrappedByDelay() {
        let view = makeView()
        let k = Kinieta(for: view).animate(.x(100), duration: 1).delay(0.5).easeIn(.cubic)
        defer { k.cancel() }
        guard case .sequence(let inner, _)? = k.timeline.first,
            case .animation(let spec)? = inner.last, let bezier = spec.easing
        else {
            Issue.record("easing was not applied inside the delay wrapper"); return
        }
        #expect(bezier == Easing.in(.cubic).bezier)

        let run = SequenceAction(inner)
        _ = run.update(frame(0.5))  // the delay
        _ = run.update(frame(0.5))  // half the animation
        #expect(approx(view.frame.origin.x, 14.5, 0.5))  // cubicIn(0.5), not linear 50
    }

    @Test func onCompleteAttachesToTheLastAction() {
        let k = Kinieta(for: makeView()).animate(.x(1), duration: 1).wait(1).onComplete {}
        defer { k.cancel() }
        guard case .pause(_, let block)? = k.timeline.last else {
            Issue.record("expected a Pause"); return
        }
        #expect(block != nil)
    }

    // MARK: Frame driver

    @Test func engineRunsTheDriverOnlyWhileActionsAreRegistered() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        #expect(!frames.isRunning)
        let view = makeView()
        let handle = view.animate(.x(100), duration: 1)
        #expect(frames.isRunning)
        frames.step(1)
        #expect(handle.state == .finished)
        #expect(!frames.isRunning)
    }

    @Test func swappingTheDriverHandsOverRunningActions() {
        let first = ManualFrameDriver.install()
        defer { first.uninstall() }
        let view = makeView()
        let handle = view.animate(.x(100), duration: 1)
        first.step(0.25)

        let second = ManualFrameDriver.install()
        #expect(!first.isRunning && second.isRunning)
        second.step(0.25)
        #expect(approx(view.frame.origin.x, 50, 0.5))
        second.uninstall()

        #expect(first.isRunning)
        first.step(0.5)
        #expect(handle.state == .finished)
        #expect(approx(view.frame.origin.x, 100))
    }

    // MARK: Frame rate

    private func sameRange(_ a: CAFrameRateRange, _ b: CAFrameRateRange) -> Bool {
        a.minimum == b.minimum && a.maximum == b.maximum && a.preferred == b.preferred
    }

    @Test func defaultFrameRateRangeFitsThePlatform() {
        #if os(visionOS)
        let expected = CAFrameRateRange(minimum: 30, maximum: 100, preferred: 90)
        #else
        let expected = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 120)
        #endif
        #expect(sameRange(Engine.defaultFrameRateRange, expected))
        #expect(sameRange(Engine.shared.preferredFrameRateRange, expected))
    }

    @Test func installedDriverTakesTheEngineFrameRateRange() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        #expect(sameRange(frames.preferredFrameRateRange, Engine.defaultFrameRateRange))
    }

    @Test func settingTheFrameRateRangeChangesItOnARunningDriver() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        defer { Engine.shared.preferredFrameRateRange = Engine.defaultFrameRateRange }
        let view = makeView()
        let handle = view.animate(.x(100), duration: 1)
        defer { handle.cancel() }
        frames.step(0.25)
        #expect(frames.isRunning)

        let sixty = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        Engine.shared.preferredFrameRateRange = sixty
        #expect(sameRange(frames.preferredFrameRateRange, sixty))
        #expect(frames.isRunning)
        #expect(frames.starts == 1)
        frames.step(0.25)
        #expect(approx(view.frame.origin.x, 50, 0.5))
    }

    @Test func invalidFrameRateRangesAreIgnored() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        defer { Engine.shared.preferredFrameRateRange = Engine.defaultFrameRateRange }
        let valid = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        Engine.shared.preferredFrameRateRange = valid
        let invalid = [
            CAFrameRateRange(minimum: 120, maximum: 60, preferred: 60),
            CAFrameRateRange(minimum: 30, maximum: 60, preferred: 120),
            CAFrameRateRange(minimum: -1, maximum: 60, preferred: 60),
            CAFrameRateRange(minimum: 30, maximum: .infinity, preferred: 60),
            CAFrameRateRange(minimum: 30, maximum: 60, preferred: .nan),
        ]
        for range in invalid {
            Engine.shared.preferredFrameRateRange = range
            #expect(sameRange(Engine.shared.preferredFrameRateRange, valid))
            #expect(sameRange(frames.preferredFrameRateRange, valid))
        }
        Engine.shared.preferredFrameRateRange = .default
        #expect(sameRange(frames.preferredFrameRateRange, .default))
    }

    @Test func displayLinkDriverAppliesTheRangeToItsRunningLink() throws {
        let driver = Engine.DisplayLinkDriver()
        #expect(sameRange(driver.preferredFrameRateRange, Engine.defaultFrameRateRange))
        driver.start { _ in }
        defer { driver.stop() }
        let link = try #require(driver.displayLink)
        #expect(sameRange(link.preferredFrameRateRange, Engine.defaultFrameRateRange))

        let sixty = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        driver.preferredFrameRateRange = sixty
        #expect(sameRange(link.preferredFrameRateRange, sixty))

        driver.stop()
        driver.start { _ in }
        let restarted = try #require(driver.displayLink)
        #expect(sameRange(restarted.preferredFrameRateRange, sixty))
    }

    // MARK: End to end through the public handle

    @Test(.timeLimit(.minutes(1)))
    func timelineRunsToCompletionAndCanBeAwaited() async {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        var completed = false
        let handle = view.animate(.x(100), duration: 0.2).onComplete { completed = true }
        #expect(handle.isRunning)
        frames.step(0.1)
        #expect(approx(view.frame.origin.x, 50, 0.5))
        #expect(!completed)
        // Runs once the test is suspended in finished(), so the waiter is resumed by the frame.
        Task { frames.step(0.1) }
        await handle.finished()
        #expect(handle.state == .finished)
        #expect(completed)
        #expect(approx(view.frame.origin.x, 100))
        await handle.finished()  // already finished: returns immediately
    }

    @Test(.timeLimit(.minutes(1)))
    func cancelStopsTheTimelineWhereItIs() async {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        var completed = false
        let handle = view.animate(.x(100), duration: 10).onComplete { completed = true }
        frames.step(1)
        handle.cancel()
        #expect(approx(view.frame.origin.x, 10, 0.5))
        #expect(handle.state == .cancelled)
        await handle.finished()  // cancelled: returns immediately
        #expect(!frames.isRunning)
        frames.step(1, count: 20)
        #expect(approx(view.frame.origin.x, 10, 0.5))
        #expect(!completed)
    }

    @Test(.timeLimit(.minutes(1)))
    func cancellingAnAwaitingTaskLeavesThePausedTimelineAlone() async {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.animate(.x(100), duration: 1)
        frames.step(0.5)
        handle.pause()
        var otherReturned = false
        let other = Task {
            await handle.finished()
            otherReturned = true
        }
        let cancelled = Task { await handle.finished() }
        while handle.waiters.count < 2 { await Task.yield() }

        cancelled.cancel()
        await cancelled.value
        #expect(handle.isPaused)
        #expect(handle.waiters.count == 1)
        #expect(!otherReturned)

        handle.resume()
        frames.step(0.5)
        await other.value
        #expect(otherReturned)
        #expect(handle.state == .finished)
        #expect(approx(view.frame.origin.x, 100))
    }

    @Test(.timeLimit(.minutes(1)))
    func anAlreadyCancelledTaskDoesNotWaitForTheTimeline() async {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.wait(.infinity)
        // Cancelled before it runs, so it reaches finished() already cancelled.
        let task = Task { await handle.finished() }
        task.cancel()
        await task.value
        #expect(handle.isRunning)
        #expect(handle.waiters.isEmpty)
        withExtendedLifetime(view) { handle.cancel() }
    }

    @Test func pauseAndResumeHoldTheTimeline() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.animate(.x(100), duration: 1)
        frames.step(0.25)
        handle.pause()
        #expect(handle.isPaused)
        frames.step(0.25, count: 4)
        #expect(approx(view.frame.origin.x, 25, 0.5))
        handle.resume()
        #expect(handle.isRunning)
        frames.step(0.25)
        #expect(approx(view.frame.origin.x, 50, 0.5))
        frames.step(0.5)
        #expect(handle.state == .finished)
        #expect(approx(view.frame.origin.x, 100))
    }

    @Test func pausingTheOnlyTimelineStopsTheDriverUntilResumed() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.animate(.x(100), duration: 1)
        frames.step(0.25)
        handle.pause()
        #expect(!frames.isRunning)
        handle.resume()
        #expect(frames.isRunning)
        frames.step(0.25)
        #expect(approx(view.frame.origin.x, 50, 0.5))
        frames.step(0.5)
        #expect(handle.state == .finished && !frames.isRunning)
    }

    @Test func driverRunsWhileAnyTimelineCanMove() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let a = makeView(), b = makeView()
        let first = a.animate(.x(100), duration: 1)
        let second = b.animate(.x(100), duration: 2)
        frames.step(0.5)
        second.pause()
        #expect(frames.isRunning)
        frames.step(0.5)
        #expect(first.state == .finished)
        #expect(!frames.isRunning)  // only the paused timeline is left
        second.resume()
        frames.step(1.5)
        #expect(second.state == .finished && !frames.isRunning)
        #expect(approx(b.frame.origin.x, 100))
    }

    @Test func pausingFromACompletionBlockStopsTheDriverInThatFrame() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.animate(.x(100), duration: 1)
        handle.onComplete { handle.pause() }.animate(.y(100), duration: 1)
        frames.step(1)
        #expect(handle.isPaused && !frames.isRunning)
    }

    @Test func groupOfHandlesCompletesOnceWhenTheLastFinishes() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let a = makeView(), b = makeView()
        var completions = 0
        let group = Kinieta.group(a.animate(.x(100), duration: 0.5), b.animate(.y(100), duration: 1)) {
            completions += 1
        }
        frames.step(0.5)
        #expect(approx(a.frame.origin.x, 100))
        #expect(approx(b.frame.origin.y, 50, 0.5))
        #expect(completions == 0 && group.isRunning)
        frames.step(0.5)
        #expect(completions == 1)
        #expect(group.state == .finished)
        #expect(approx(b.frame.origin.y, 100))
        frames.step(0.5)
        #expect(completions == 1)
    }

    @Test func cancellingAGroupedHandleStopsOnlyThatChild() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let a = makeView(), b = makeView()
        let first = a.animate(.x(100), duration: 1)
        let second = b.animate(.x(100), duration: 1)
        let group = Kinieta.group(first, second)
        frames.step(0.25)
        first.cancel()
        #expect(approx(a.frame.origin.x, 25, 0.5))
        frames.step(0.25, count: 3)
        #expect(group.state == .finished)
        #expect(approx(a.frame.origin.x, 25, 0.5))
        #expect(approx(b.frame.origin.x, 100))
        #expect(first.state == .cancelled && second.state == .finished)
    }

    @Test(.timeLimit(.minutes(1)))
    func cancellingAGroupCancelsEveryChild() async {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let a = makeView(), b = makeView()
        let first = a.animate(.x(100), duration: 1)
        let second = b.animate(.x(100), duration: 2)
        let group = Kinieta.group(first, second)
        frames.step(0.25)
        group.cancel()
        #expect(group.state == .cancelled)
        #expect(first.state == .cancelled && second.state == .cancelled)
        await first.finished()  // cancelled: returns immediately
        await second.finished()
        #expect(!frames.isRunning)
        #expect(approx(a.frame.origin.x, 25, 0.5))
        #expect(approx(b.frame.origin.x, 12.5, 0.5))
    }

    @Test(.timeLimit(.minutes(1)))
    func cancellingAGroupResumesChildWaiters() async {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let child = view.animate(.x(100), duration: 10)
        let group = Kinieta.group(child)
        frames.step(1)
        // Runs once the test is suspended in finished().
        Task { group.cancel() }
        await child.finished()
        #expect(child.state == .cancelled)
    }

    @Test func pausingAGroupPausesItsChildren() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let a = makeView(), b = makeView()
        let first = a.animate(.x(100), duration: 1)
        let second = b.animate(.x(100), duration: 1)
        let group = Kinieta.group(first, second)
        frames.step(0.25)
        group.pause()
        #expect(group.isPaused && first.isPaused && second.isPaused)
        #expect(!frames.isRunning)
        first.resume()  // cannot run ahead of its paused group
        #expect(first.isPaused && !frames.isRunning)
        frames.step(0.25, count: 4)
        #expect(approx(a.frame.origin.x, 25, 0.5))
        group.resume()
        #expect(group.isRunning && first.isRunning && second.isRunning)
        frames.step(0.75)
        #expect(group.state == .finished && first.state == .finished && second.state == .finished)
        #expect(approx(a.frame.origin.x, 100) && approx(b.frame.origin.x, 100))
    }

    @Test func cancellingAPausedChildLetsItsGroupMoveOn() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let a = makeView(), b = makeView()
        let first = a.animate(.x(100), duration: 1)
        let second = b.animate(.x(100), duration: 1)
        let group = Kinieta.group(first, second)
        frames.step(0.25)
        first.pause()
        second.pause()
        #expect(group.isRunning && !frames.isRunning)
        first.cancel()
        #expect(frames.isRunning)  // the group has to drop it
        frames.step()
        #expect(group.isRunning && !frames.isRunning)
        second.resume()
        frames.step(0.75)
        #expect(group.state == .finished && second.state == .finished)
        #expect(approx(b.frame.origin.x, 100))
    }

    @Test func aHandleListedTwiceRunsAtNormalSpeed() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.animate(.x(100), duration: 1)
        Kinieta.group(handle, handle)
        frames.step(0.25)
        #expect(approx(view.frame.origin.x, 25, 0.5))
    }

    @Test func aHandleAlreadyInAGroupIsLeftOutOfAnother() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.animate(.x(100), duration: 1)
        let first = Kinieta.group(handle)
        var secondCompleted = false
        let second = Kinieta.group(handle) { secondCompleted = true }
        frames.step(0.25)
        #expect(approx(view.frame.origin.x, 25, 0.5))
        #expect(secondCompleted && second.state == .finished)
        second.cancel()  // already finished: must not reach the handle
        #expect(handle.isRunning && first.isRunning)
        frames.step(0.75)
        #expect(handle.state == .finished && first.state == .finished)
    }

    @Test func groupingAFinishedHandleDoesNotRunItsCompletionAgain() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        var completions = 0
        let view = makeView()
        let handle = view.animate(.x(100), duration: 0.5)
        handle.onComplete { completions += 1 }
        frames.step(0.5)
        #expect(handle.state == .finished && completions == 1)
        var groupCompleted = false
        let group = Kinieta.group(handle) { groupCompleted = true }
        frames.step(0.5)
        #expect(completions == 1)
        #expect(groupCompleted && group.state == .finished)
        #expect(handle.state == .finished)
    }

    @Test func groupingKeepsTheEngineRunning() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.animate(.x(100), duration: 1)
        let starts = frames.starts
        Kinieta.group(handle)
        #expect(frames.starts == starts && frames.stops == 0)
    }

    @Test func timelineIsCancelledWhenTheViewIsReleased() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        var view: UIView? = makeView()
        let handle = view!.animate(.x(100), duration: 10)
        frames.step()
        #expect(handle.view != nil && handle.isRunning)
        view = nil
        frames.step()
        #expect(handle.view == nil)
        #expect(handle.state == .cancelled)
    }

    @Test(.timeLimit(.minutes(1)))
    func releasingTheViewSkipsTheRestOfTheTimeline() async {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        var view: UIView? = makeView()
        var animationCompleted = false, waitCompleted = false
        let handle = view!.animate(.x(100), duration: 1)
            .onComplete { animationCompleted = true }
            .wait(10)
            .onComplete { waitCompleted = true }
        frames.step(0.5)
        view = nil
        frames.step()
        #expect(handle.state == .cancelled)
        #expect(!frames.isRunning)
        await handle.finished()  // cancelled: returns immediately
        frames.step(1, count: 20)
        #expect(!animationCompleted && !waitCompleted)
    }

    @Test func releasingTheViewDuringAWaitEndsTheTimelineOnTheNextFrame() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        var view: UIView? = makeView()
        var waitCompleted = false
        let handle = view!.animate(.x(100), duration: 0.5).wait(10).onComplete { waitCompleted = true }
        frames.step(1)
        #expect(handle.isRunning)
        view = nil
        frames.step()
        #expect(handle.state == .cancelled && !frames.isRunning)
        #expect(!waitCompleted)
    }

    @Test func releasingTheViewFromACompletionBlockStopsTheTimelineInThatFrame() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        var view: UIView? = makeView()
        var waitCompleted = false
        let handle = view!.animate(.x(100), duration: 1)
            .onComplete { view = nil }
            .wait(0)
            .onComplete { waitCompleted = true }
        frames.step(1.5)  // the leftover half frame would otherwise finish the wait
        #expect(view == nil)
        #expect(handle.state == .cancelled)
        #expect(!waitCompleted)
    }

    @Test func releasingTheLastViewFromTheLastCompletionBlockStillFinishes() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        var view: UIView? = makeView()
        let handle = view!.animate(.x(100), duration: 1).onComplete { view = nil }
        frames.step(1)
        #expect(view == nil)
        #expect(handle.state == .finished)
    }

    @Test func releasingTheViewFromACompletionBlockInsideThenStopsTheTimelineInThatFrame() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        var view: UIView? = makeView()
        var waitCompleted = false, stepCompleted = false
        let handle = view!.wait(1)
            .onComplete { view = nil }
            .wait(0)
            .onComplete { waitCompleted = true }
            .then()
            .onComplete { stepCompleted = true }
        frames.step(1.5)
        #expect(view == nil)
        #expect(!waitCompleted && !stepCompleted)
        #expect(handle.state == .cancelled)
        #expect(!frames.isRunning)
    }

    @Test func releasingTheViewFromACompletionBlockInsideDelayRunsNoLaterCompletion() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        var view: UIView? = makeView()
        var delayedCompleted = false
        let handle = view!.animate(.x(100), duration: 1)
            .onComplete { view = nil }
            .delay(0.5)
            .onComplete { delayedCompleted = true }
        frames.step(1.5)
        #expect(view == nil)
        #expect(!delayedCompleted)
        #expect(handle.state == .cancelled)
    }

    @Test func releasingTheViewFromACompletionBlockInsideParallelSkipsTheOtherMembers() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        var view: UIView? = makeView()
        var otherCompleted = false, groupCompleted = false
        let handle = view!.animate(.x(100), duration: 1)
            .onComplete { view = nil }
            .wait(1)
            .onComplete { otherCompleted = true }
            .parallel()
            .onComplete { groupCompleted = true }
        frames.step(1)
        #expect(view == nil)
        #expect(!otherCompleted && !groupCompleted)
        #expect(handle.state == .cancelled)
    }

    @Test func releasingTheViewFromTheLastMemberOfParallelSkipsItsCompletion() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        var view: UIView? = makeView()
        var groupCompleted = false
        let handle = view!.wait(0.5)
            .animate(.x(100), duration: 1)
            .onComplete { view = nil }
            .parallel()
            .onComplete { groupCompleted = true }
        frames.step(1)
        #expect(view == nil)
        #expect(!groupCompleted)
        #expect(handle.state == .cancelled)
    }

    @Test func releasingTheViewFromTheLastCompletionBlockInsideThenStillFinishes() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        var view: UIView? = makeView()
        let handle = view!.animate(.x(100), duration: 1).onComplete { view = nil }.then()
        frames.step(1)
        #expect(view == nil)
        #expect(handle.state == .finished)
    }

    @Test func pausedTimelineIsCancelledOnceItsViewIsReleased() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        var view: UIView? = makeView()
        let other = makeView()
        let handle = view!.animate(.x(100), duration: 1)
        other.animate(.x(100), duration: 1)
        frames.step(0.25)
        handle.pause()
        view = nil
        frames.step(0.25)
        #expect(handle.state == .cancelled)
    }

    @Test func aGroupMovesOnWhenAChildLosesItsView() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        var a: UIView? = makeView()
        let b = makeView()
        var groupCompleted = false
        let first = a!.animate(.x(100), duration: 10)
        let second = b.animate(.x(100), duration: 1)
        let group = Kinieta.group(first, second) { groupCompleted = true }
        frames.step(0.5)
        a = nil
        frames.step()
        #expect(first.state == .cancelled)
        #expect(group.isRunning && second.isRunning)
        frames.step(0.5)
        #expect(second.state == .finished)
        #expect(groupCompleted && group.state == .finished)
        #expect(!frames.isRunning)
    }

    @Test(.timeLimit(.minutes(1)))
    func aPausedTimelineIsCancelledWithoutAFrameWhenItsViewIsReleased() async {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        var view: UIView? = makeView()
        var completed = false
        let handle = view!.animate(.x(100), duration: 1).onComplete { completed = true }
        frames.step(0.25)
        handle.pause()
        #expect(!frames.isRunning)
        view = nil
        await handle.finished()  // returns although no frame runs
        #expect(handle.state == .cancelled)
        #expect(!frames.isRunning && frames.starts == 1)
        #expect(!completed)
    }

    @Test(.timeLimit(.minutes(1)))
    func anInfiniteWaitIsCancelledWithoutAFrameWhenItsViewIsReleased() async {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        var view: UIView? = makeView()
        var waitCompleted = false
        let handle = view!.animate(.x(100), duration: 0.5).wait(.infinity).onComplete { waitCompleted = true }
        frames.step(0.5, count: 2)
        #expect(handle.isRunning && !frames.isRunning)
        view = nil
        await handle.finished()
        #expect(handle.state == .cancelled)
        #expect(!frames.isRunning && frames.starts == 1)
        #expect(!waitCompleted)
    }

    @Test(.timeLimit(.minutes(1)))
    func aTimelineInAPausedGroupIsCancelledWhenItsViewIsReleased() async {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        var a: UIView? = makeView()
        let b = makeView()
        var groupCompleted = false
        let first = a!.animate(.x(100), duration: 1)
        let second = b.animate(.x(100), duration: 1)
        let group = Kinieta.group(first, second) { groupCompleted = true }
        frames.step(0.5)
        group.pause()
        a = nil
        await first.finished()
        #expect(first.state == .cancelled)
        #expect(group.isPaused && second.isPaused)
        group.resume()
        frames.step(0.5)
        #expect(second.state == .finished)
        #expect(groupCompleted && group.state == .finished)
    }

    @Test(.timeLimit(.minutes(1)))
    func everyTimelineOfAReleasedViewIsCancelled() async {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        var view: UIView? = makeView()
        let paused = view!.animate(.x(100), duration: 1)
        let waiting = view!.wait(.infinity)
        let finished = view!.animate(.alpha(0))
        frames.step()
        paused.pause()
        #expect(finished.state == .finished && !frames.isRunning)
        view = nil
        await paused.finished()
        await waiting.finished()
        #expect(paused.state == .cancelled && waiting.state == .cancelled)
        #expect(finished.state == .finished)
    }

    @Test func aViewKeepsNoHandleAlive() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        weak var handle: Kinieta?
        do {
            let made = view.wait(.infinity)
            handle = made
        }
        #expect(handle == nil)
    }

    @Test(.timeLimit(.minutes(1)))
    func cancelFromACompletionBlockStopsTheTimelineInThatFrame() async {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        var laterCompleted = false
        let handle = view.animate(.x(100), duration: 1)
        handle.onComplete { handle.cancel() }
            .animate(.alpha(0))
            .onComplete { laterCompleted = true }
        frames.step(1.5)  // the leftover half frame must not reach the alpha animation
        #expect(approx(view.frame.origin.x, 100))
        #expect(view.alpha == 1)
        #expect(!laterCompleted)
        #expect(handle.state == .cancelled)
        await handle.finished()  // cancelled: returns immediately
        #expect(!frames.isRunning)
    }

    @Test func cancelFromTheLastCompletionBlockStaysCancelled() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.animate(.x(100), duration: 1)
        handle.onComplete { handle.cancel() }
        frames.step(1)
        #expect(approx(view.frame.origin.x, 100))
        #expect(handle.state == .cancelled)
        #expect(!frames.isRunning)
    }

    @Test func pauseFromACompletionBlockHoldsTheNextActionAtItsStart() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.animate(.x(100), duration: 1)
        handle.onComplete { handle.pause() }
            .animate(.y(100), duration: 1)
        frames.step(1.5)
        #expect(approx(view.frame.origin.x, 100))
        #expect(view.frame.origin.y == 0)
        #expect(handle.isPaused)
        frames.step(0.25, count: 4)
        #expect(view.frame.origin.y == 0)
        handle.resume()
        frames.step(0.25)
        #expect(approx(view.frame.origin.y, 25, 0.5))
        frames.step(0.75)
        #expect(handle.state == .finished)
        #expect(approx(view.frame.origin.y, 100))
    }

    @Test func cancelFromACompletionBlockInsideThenStopsTheTimelineInThatFrame() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        var laterCompleted = false
        let handle = view.animate(.x(100), duration: 1)
        handle.onComplete { handle.cancel() }
            .animate(.alpha(0))
            .onComplete { laterCompleted = true }
            .then()
        frames.step(1.5)
        #expect(approx(view.frame.origin.x, 100))
        #expect(view.alpha == 1)
        #expect(!laterCompleted)
        #expect(handle.state == .cancelled)
        #expect(!frames.isRunning)
    }

    @Test func cancelFromACompletionBlockInsideDelayRunsNoLaterCompletion() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        var delayedCompleted = false
        let handle = view.animate(.x(100), duration: 1)
        handle.onComplete { handle.cancel() }
            .delay(0.5)
            .onComplete { delayedCompleted = true }
        frames.step(1.5)
        #expect(approx(view.frame.origin.x, 100))
        #expect(!delayedCompleted)
        #expect(handle.state == .cancelled)
    }

    @Test func cancelFromACompletionBlockInsideParallelLeavesTheOtherMembers() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        var otherCompleted = false, groupCompleted = false
        let handle = view.animate(.x(100), duration: 1)
        handle.onComplete { handle.cancel() }
            .animate(.y(100), duration: 1)
            .onComplete { otherCompleted = true }
            .parallel()
            .onComplete { groupCompleted = true }
        frames.step(0.5)
        #expect(approx(view.frame.origin.y, 50, 0.5))
        frames.step(0.5)
        #expect(approx(view.frame.origin.x, 100))
        #expect(approx(view.frame.origin.y, 50, 0.5))
        #expect(!otherCompleted && !groupCompleted)
        #expect(handle.state == .cancelled)
    }

    @Test func pauseFromACompletionBlockInsideThenHoldsTheNextActionAtItsStart() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.animate(.x(100), duration: 1)
        handle.onComplete { handle.pause() }
            .animate(.y(100), duration: 1)
            .then()
        frames.step(1.5)
        #expect(view.frame.origin.y == 0)
        #expect(handle.isPaused && !frames.isRunning)
        handle.resume()
        frames.step(0.25)
        #expect(approx(view.frame.origin.y, 25, 0.5))
        frames.step(0.75)
        #expect(approx(view.frame.origin.y, 100))
        #expect(handle.state == .finished)
    }

    @Test func pauseFromACompletionBlockInsideParallelHoldsTheOtherMembers() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        var groupCompletions = 0
        let handle = view.animate(.x(100), duration: 1)
        handle.onComplete { handle.pause() }
            .animate(.y(100), duration: 2)
            .parallel()
            .onComplete { groupCompletions += 1 }
        frames.step(1)
        #expect(approx(view.frame.origin.x, 100))
        #expect(view.frame.origin.y == 0)
        #expect(handle.isPaused)
        handle.resume()
        frames.step(1)
        #expect(approx(view.frame.origin.y, 50, 0.5))
        frames.step(1)
        #expect(approx(view.frame.origin.y, 100))
        #expect(groupCompletions == 1)
        #expect(handle.state == .finished)
    }

    @Test func pauseFromTheLastCompletionBlockInAGroupHoldsItsCompletion() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        var groupCompletions = 0
        let handle = view.animate(.x(100), duration: 1)
        handle.onComplete { handle.pause() }
            .parallel()
            .onComplete { groupCompletions += 1 }
        frames.step(1)
        #expect(groupCompletions == 0)
        #expect(handle.isPaused)
        handle.resume()
        frames.step()
        #expect(groupCompletions == 1)
        #expect(handle.state == .finished)
    }

    @Test func cancellingAGroupHandleFromAMemberCompletionSkipsTheGroupCompletion() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let a = makeView(), b = makeView()
        var group: Kinieta?
        var groupCompleted = false
        let first = a.animate(.x(100), duration: 1).onComplete { group?.cancel() }
        let second = b.animate(.x(100), duration: 1)
        group = Kinieta.group(first, second) { groupCompleted = true }
        frames.step(1)
        #expect(approx(a.frame.origin.x, 100))
        #expect(b.frame.origin.x == 0)
        #expect(!groupCompleted)
        #expect(group?.state == .cancelled && second.state == .cancelled)
        #expect(!frames.isRunning)
    }

    // MARK: Extending a started or finished timeline

    @Test(.timeLimit(.minutes(1)))
    func appendingToAFinishedHandleRunsItAgain() async {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.animate(.x(10), duration: 0.1)
        frames.step(0.1)
        #expect(handle.state == .finished)
        #expect(!frames.isRunning)

        handle.animate(.x(100), duration: 1)
        #expect(handle.isRunning)
        #expect(frames.isRunning)
        frames.step(0.5)
        #expect(approx(view.frame.origin.x, 55, 0.5))
        // Runs once the test is suspended in finished(), so the waiter is resumed by the frame.
        Task { frames.step(0.5) }
        await handle.finished()
        #expect(handle.state == .finished)
        #expect(approx(view.frame.origin.x, 100))
    }

    @Test func emptyHandleBuiltAFrameLaterStillAnimates() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = Kinieta(for: view)
        frames.step()
        #expect(handle.state == .finished)
        handle.animate(.x(100), duration: 1)
        frames.step(0.5)
        #expect(approx(view.frame.origin.x, 50, 0.5))
        frames.step(0.5)
        #expect(handle.state == .finished)
        #expect(approx(view.frame.origin.x, 100))
    }

    @Test func repeatAfterTheFirstFramePlaysTheWholeChainTwice() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        var laps = 0
        let handle = view.animate(.x(100), duration: 1)
            .animate(.x(0), duration: 1)
            .onComplete { laps += 1 }
        frames.step(0.5)
        handle.repeat(times: 1)
        #expect(handle.timeline.map { $0.description } == Array(repeating: "Animation (x)", count: 4))
        frames.step(0.5)
        #expect(approx(view.frame.origin.x, 100))
        frames.step(1)
        #expect(approx(view.frame.origin.x, 0))
        #expect(laps == 1)
        frames.step(1)
        #expect(approx(view.frame.origin.x, 100))
        frames.step(1)
        #expect(approx(view.frame.origin.x, 0))
        #expect(laps == 2)
        #expect(handle.state == .finished)
    }

    @Test func modifiersNeverReachAnActionThatHasStarted() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        var completed = false
        let handle = view.animate(.x(100), duration: 1)
        frames.step(0.25)
        handle.easeIn(.cubic).onComplete { completed = true }.delay(1)
        frames.step(0.25)
        #expect(approx(view.frame.origin.x, 50, 0.5))  // still linear, not delayed
        handle.animate(.y(100), duration: 1).easeIn(.cubic)
        frames.step(0.5)
        #expect(approx(view.frame.origin.x, 100))
        #expect(!completed)
        frames.step(0.5)
        #expect(approx(view.frame.origin.y, 14.5, 0.5))  // cubicIn(0.5), not linear 50
    }

    @Test func extendingFromItsOwnLastCompletionBlockContinuesInTheSameFrame() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.animate(.x(100), duration: 1)
        handle.onComplete { handle.animate(.y(100), duration: 1) }
        frames.step(1.5)
        #expect(approx(view.frame.origin.x, 100))
        #expect(approx(view.frame.origin.y, 50, 0.5))
        frames.step(0.5)
        #expect(handle.state == .finished)
    }

    @Test func handleExtendedInTheFrameItFinishedKeepsRunning() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let first = makeView()
        let second = makeView()
        let early = first.animate(.x(100), duration: 1)
        // Updated after `early` in the same frame, once `early` has finished.
        second.animate(.x(100), duration: 1).onComplete { early.animate(.y(100), duration: 1) }
        frames.step(1)
        #expect(early.isRunning)
        frames.step(0.5)
        #expect(approx(first.frame.origin.y, 50, 0.5))
        frames.step(0.5)
        #expect(early.state == .finished)
        #expect(approx(first.frame.origin.y, 100))
    }

    @Test func cancelledHandleIgnoresAppends() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.animate(.x(100), duration: 1)
        handle.cancel()
        handle.animate(.y(100), duration: 1).repeat(times: 2)
        #expect(handle.state == .cancelled)
        #expect(handle.timeline.isEmpty)
        #expect(!frames.isRunning)
        frames.step(1)
        #expect(view.frame.origin.y == 0)
    }

    @Test func finishedHandleReleasesBlocksThatCaptureIt() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        weak var weakHandle: Kinieta?
        do {
            let handle = makeView().animate(.x(100), duration: 1)
            handle.onComplete { _ = handle.state }
            weakHandle = handle
        }
        #expect(weakHandle != nil)
        frames.step(1)
        #expect(weakHandle == nil)
    }

    @Test func groupedHandleExtendedAfterFinishingRejoinsItsGroup() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let a = makeView(), b = makeView()
        var completions = 0
        let first = a.animate(.x(100), duration: 0.5)
        let second = b.animate(.y(100), duration: 1)
        let group = Kinieta.group(first, second) { completions += 1 }
        frames.step(0.5)
        #expect(first.state == .finished)
        first.animate(.alpha(0), duration: 1)
        #expect(first.isRunning)
        frames.step(0.5)
        #expect(second.state == .finished)
        #expect(group.isRunning && completions == 0)
        group.pause()
        #expect(first.isPaused)
        frames.step(0.5)
        #expect(approx(a.alpha, 0.5, 0.01))
        group.resume()
        frames.step(0.5)
        #expect(approx(a.alpha, 0, 0.01))
        #expect(first.state == .finished && group.state == .finished)
        #expect(completions == 1)
    }

    @Test func groupedHandleExtendedAfterItsGroupFinishedRunsOnItsOwn() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.animate(.x(100), duration: 0.5)
        let group = Kinieta.group(handle)
        frames.step(0.5)
        #expect(group.state == .finished)
        handle.animate(.y(100), duration: 1)
        #expect(handle.isRunning && frames.isRunning)
        frames.step(0.5)
        #expect(approx(view.frame.origin.y, 50, 0.5))
        group.cancel()  // already finished: must not reach the handle
        #expect(handle.isRunning)
        frames.step(0.5)
        #expect(handle.state == .finished)
        #expect(approx(view.frame.origin.y, 100))
    }

    // MARK: Chaining on a group handle

    @Test func onCompleteOnAGroupHandleFiresOnceAfterEveryMemberFinishes() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let a = makeView(), b = makeView()
        var completions = 0
        let group = Kinieta.group(a.animate(.x(100), duration: 0.5), b.animate(.y(100), duration: 1))
            .onComplete { completions += 1 }
        frames.step(0.5)
        #expect(completions == 0 && group.isRunning)
        frames.step(0.5)
        #expect(completions == 1 && group.state == .finished)
        frames.step(0.5)
        #expect(completions == 1)
    }

    @Test func delayOnAGroupHandlePostponesTheWholeGroup() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let a = makeView(), b = makeView()
        var completed = false
        let group = Kinieta.group(a.animate(.x(100), duration: 1), b.animate(.y(100), duration: 1))
            .delay(0.5)
            .onComplete { completed = true }
        frames.step(0.5)
        #expect(approx(a.frame.origin.x, 0) && approx(b.frame.origin.y, 0))
        frames.step(0.5)
        #expect(approx(a.frame.origin.x, 50, 0.5) && approx(b.frame.origin.y, 50, 0.5))
        #expect(!completed && group.isRunning)
        frames.step(0.5)
        #expect(completed && group.state == .finished)
        #expect(approx(a.frame.origin.x, 100) && approx(b.frame.origin.y, 100))
    }

    @Test func waitOnAGroupHandleChainsAfterTheGroup() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let a = makeView(), b = makeView()
        let first = a.animate(.x(100), duration: 0.5)
        let second = b.animate(.y(100), duration: 1)
        var groupCompleted = false, waitCompleted = false
        let group = Kinieta.group(first, second) { groupCompleted = true }
            .wait(1)
            .onComplete { waitCompleted = true }
        frames.step(1)
        #expect(groupCompleted && !waitCompleted)
        #expect(first.state == .finished && second.state == .finished && group.isRunning)
        frames.step(0.5)
        #expect(!waitCompleted && group.isRunning)
        frames.step(0.5)
        #expect(waitCompleted && group.state == .finished)
    }

    @Test func repeatOnAGroupHandleReplaysTheGroup() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let a = makeView(), b = makeView()
        var completions = 0
        let group = Kinieta.group(
            a.animate(.x(100), duration: 0.5).animate(.x(0), duration: 0.5),
            b.animate(.y(100), duration: 1)
        ) { completions += 1 }
        .repeat()
        frames.step(1)
        #expect(completions == 1 && group.isRunning)
        frames.step(0.5)
        #expect(approx(a.frame.origin.x, 100) && approx(b.frame.origin.y, 100))
        frames.step(0.5)
        #expect(completions == 2 && group.state == .finished)
        #expect(approx(a.frame.origin.x, 0))
    }

    @Test func animateOnAGroupHandleIsIgnored() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        var completed = false
        let group = Kinieta.group(view.animate(.x(100), duration: 1))
            .animate(.y(100), duration: 1)
            .onComplete { completed = true }  // reaches the group, not the ignored animation
        #expect(descriptions(group) == ["Timelines"])
        frames.step(1)
        #expect(completed && group.state == .finished)
        #expect(approx(view.frame.origin.x, 100) && approx(view.frame.origin.y, 0))
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

    @Test func easingThatFollowsNoAnimationIsReportedAndChangesNothing() {
        let cases: [(step: String, build: (Kinieta) -> Kinieta)] = [
            ("wait", { $0.animate(.x(1), duration: 1).wait(1) }),
            ("parallel() or then()", { $0.animate(.x(1), duration: 1).animate(.y(1), duration: 1).parallel() }),
            ("parallel() or then()", { $0.animate(.x(1), duration: 1).then() }),
            ("delayed wait", { $0.wait(1).delay(1) }),
        ]
        for (step, build) in cases {
            let k = build(Kinieta(for: makeView()))
            defer { k.cancel() }
            let before = descriptions(k)
            let calls = ignoredCalls { k.easeOut() }
            #expect(calls.map(\.message) == ["easing(_:) follows a \(step), not an animation; ignoring it"])
            #expect(descriptions(k) == before)
        }
    }

    @Test func easingAGroupHandleIsReported() {
        let group = Kinieta.group(makeView().animate(.x(1), duration: 1))
        defer { group.cancel() }
        let calls = ignoredCalls { group.easeInOut(.back) }
        #expect(calls.map(\.message) == ["easing(_:) follows a Kinieta.group, not an animation; ignoring it"])
    }

    @Test func modifiersOnAnEmptyTimelineAreReported() {
        let k = Kinieta(for: makeView())
        defer { k.cancel() }
        let calls = ignoredCalls {
            k.delay(1).onComplete {}.easeIn().parallel().then().repeat(times: 2)
        }
        #expect(
            calls.map(\.message) == [
                "delay(_:) has no action to postpone: the timeline is empty; ignoring it",
                "onComplete(_:) has no action to follow: the timeline is empty; ignoring it",
                "easing(_:) has no animation to ease: the timeline is empty; ignoring it",
                "parallel() has nothing to run together: the timeline is empty; ignoring it",
                "then() has nothing to seal: the timeline is empty; ignoring it",
                "repeat(times:) has nothing to repeat: the timeline is empty",
            ])
        #expect(k.timeline.isEmpty)
    }

    @Test func modifiersAfterEveryActionHasStartedAreReported() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.animate(.x(100), duration: 1)
        defer { handle.cancel() }
        frames.step(0.25)
        #expect(handle.state == .running)
        let calls = ignoredCalls { handle.delay(1).onComplete {}.easeIn().parallel().then() }
        let reason = "every action in it has already started; ignoring it"
        #expect(
            calls.map(\.message) == [
                "delay(_:) has no action to postpone: \(reason)",
                "onComplete(_:) has no action to follow: \(reason)",
                "easing(_:) has no animation to ease: \(reason)",
                "parallel() has nothing to run together: \(reason)",
                "then() has nothing to seal: \(reason)",
            ])
    }

    @Test func thenOrParallelWithNothingNewToGatherIsReported() {
        let k = Kinieta(for: makeView()).animate(.x(1), duration: 1).animate(.y(1), duration: 1).parallel()
        defer { k.cancel() }
        let calls = ignoredCalls { k.parallel().then() }
        let reason = "nothing was added since the last then() or parallel(); ignoring it"
        #expect(
            calls.map(\.message) == [
                "parallel() has nothing to run together: \(reason)",
                "then() has nothing to seal: \(reason)",
            ])
        #expect(descriptions(k) == ["Group (2)"])
    }

    @Test(arguments: [0, -1])
    func repeatingZeroOrFewerTimesIsReported(times: Int) {
        let k = Kinieta(for: makeView()).animate(.x(1), duration: 1)
        defer { k.cancel() }
        let calls = ignoredCalls { k.repeat(times: times) }
        #expect(calls.map(\.message) == ["repeat(times:) was given \(times) times; ignoring it"])
        #expect(descriptions(k) == ["Animation (x)"])
    }

    @Test func animateOnAGroupHandleIsReported() {
        let group = Kinieta.group(makeView().animate(.x(1), duration: 1))
        defer { group.cancel() }
        let calls = ignoredCalls { group.animate(.y(1), duration: 1) }
        #expect(
            calls.map(\.message) == [
                "animate(_:duration:) was called on a group handle, which has no view; ignoring it"
            ])
    }

    @Test func warningsCarryTheCallSite() {
        let k = Kinieta(for: makeView()).wait(1)
        defer { k.cancel() }
        let easeLine: UInt = #line + 1
        let easing = ignoredCalls { k.easeIn() }
        #expect(easing.map(\.site) == [IgnoredCall.Site(fileID: #fileID, line: easeLine)])
        let completionLine: UInt = #line + 1
        let completion = ignoredCalls { Kinieta(for: makeView()).onComplete {}.cancel() }
        #expect(completion.map(\.site) == [IgnoredCall.Site(fileID: #fileID, line: completionLine)])
        let thenLine: UInt = #line + 1
        let then = ignoredCalls { k.then().then() }
        #expect(then.map(\.site) == [IgnoredCall.Site(fileID: #fileID, line: thenLine)])
    }

    @Test func validChainsRaiseNoWarnings() {
        var handles: [Kinieta] = []
        let calls = ignoredCalls {
            handles.append(
                makeView().animate(.x(250), .y(500), duration: 0.5).easeInOut(.cubic)
                    .wait(0.5)
                    .animate(.x(300), .y(200), duration: 0.5).easeInOut(.cubic)
                    .animate(.x(0), .y(0), duration: 0.5).delay(0.2)
                    .repeat(times: 1))
            handles.append(
                makeView().animate(.x(200), duration: 1.0).easeInOut(.cubic)
                    .animate(.alpha(0), duration: 0.2).delay(0.8).easeOut()
                    .parallel()
                    .onComplete {})
            handles.append(
                makeView().animate(.x(300), duration: 1.0)
                    .then()
                    .animate(.x(200), duration: 1.0)
                    .animate(.alpha(0), duration: 0.2)
                    .parallel())
            let slide = makeView().animate(.x(374), duration: 1.0).easeInOut(.cubic)
            let spin = makeView().animate(.rotation(degrees: 360), .alpha(0), duration: 1.2)
            handles.append(
                Kinieta.group(slide, spin).delay(0.5).onComplete {}.wait(1.0).onComplete {}.repeat(times: 1))
            handles.append(Kinieta(for: makeView()).animate(.x(1), duration: 1).easeIn().wait(1).onComplete {})
        }
        for handle in handles { handle.cancel() }
        #expect(calls.isEmpty)
    }
    #endif

    // MARK: Invalid durations

    @Test func negativeWaitIsZeroAndDoesNotFastForward() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        view.wait(-5).animate(.x(100), duration: 1)
        frames.step(0.5)
        #expect(approx(view.frame.origin.x, 50, 0.5))
    }

    @Test func negativeDelayIsZeroAndDoesNotFastForward() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        view.animate(.y(10), duration: 0).animate(.x(100), duration: 1).delay(-5)
        frames.step(0.5)
        #expect(approx(view.frame.origin.x, 50, 0.5))
    }

    @Test func nanWaitFinishesWithinOneFrame() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.wait(.nan)
        frames.step()
        #expect(handle.state == .finished)
        #expect(!frames.isRunning)
    }

    @Test(arguments: [-1, .nan, .infinity, -.infinity] as [TimeInterval])
    func invalidAnimationDurationSnapsWithinOneFrame(duration: TimeInterval) {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.animate(.x(100), duration: duration)
        frames.step()
        #expect(view.frame.origin.x == 100)
        #expect(handle.state == .finished)
    }

    @Test func infiniteWaitHoldsUntilCancelled() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.wait(.infinity).animate(.x(100), duration: 1)
        frames.step(1, count: 100)
        #expect(handle.isRunning)
        #expect(view.frame.origin.x == 0)
        #expect(!frames.isRunning)  // nothing can change until it is cancelled
        handle.cancel()
        #expect(!frames.isRunning)
        #expect(handle.state == .cancelled)
    }

    @Test func infiniteWaitInAGroupStopsTheDriverOnceTheOthersFinish() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let waiting = view.wait(.infinity)
        let group = Kinieta.group(waiting, view.animate(.x(100), duration: 1))
        frames.step(0.5)
        #expect(frames.isRunning)
        frames.step(0.5)
        #expect(approx(view.frame.origin.x, 100))
        #expect(group.isRunning && !frames.isRunning)
        waiting.cancel()
        #expect(frames.isRunning)
        frames.step()
        #expect(group.state == .finished && !frames.isRunning)
    }

    @Test(.timeLimit(.minutes(1)))
    func aPausedTimelineIsReleasedWithItsHandle() async {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        weak var sequence: SequenceAction?
        weak var captured: NSObject?
        do {
            let token = NSObject()
            captured = token
            let handle = view.animate(.x(100), duration: 1).onComplete { _ = token }
            sequence = handle.mainSequence
            frames.step(0.25)
            handle.pause()
        }
        // Released by the refresh the handle's deinit schedules.
        while sequence != nil || captured != nil { await Task.yield() }
        #expect(!frames.isRunning)
        #expect(approx(view.frame.origin.x, 25, 0.5))
    }

    @Test(.timeLimit(.minutes(1)))
    func anInfiniteWaitIsReleasedWithItsHandle() async {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        weak var sequence: SequenceAction?
        do {
            let handle = view.animate(.x(100), duration: 0.5).wait(.infinity).animate(.x(0), duration: 1)
            sequence = handle.mainSequence
        }
        frames.step(0.5, count: 2)
        #expect(!frames.isRunning)
        while sequence != nil { await Task.yield() }
        #expect(approx(view.frame.origin.x, 100))
    }

    @Test func anIdleTimelineWhoseHandleIsKeptStays() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.animate(.x(100), duration: 1)
        frames.step(0.25)
        handle.pause()
        Engine.shared.refreshDriver()
        handle.resume()
        frames.step(0.75)
        #expect(handle.state == .finished)
        #expect(approx(view.frame.origin.x, 100))
    }

    @Test func aGroupWhoseHandleIsGoneStaysWhileAMemberCanMoveIt() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let waiting = view.wait(.infinity)
        weak var sequence: SequenceAction?
        var completed = false
        do {
            let group = Kinieta.group(waiting, view.animate(.x(100), duration: 1)) { completed = true }
            sequence = group.mainSequence
        }
        frames.step(1)
        #expect(!frames.isRunning)
        Engine.shared.refreshDriver()
        #expect(sequence != nil)  // `waiting` can still be cancelled, which ends the group
        waiting.cancel()
        frames.step()
        #expect(completed)
        #expect(sequence == nil)
    }

    @Test(.timeLimit(.minutes(1)))
    func aMemberOfAPausedGroupRunsOnAfterTheGroupHandleIsReleased() async {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let member = view.animate(.x(100), duration: 1)
        let other = view.animate(.alpha(0.5), duration: 0.5)
        weak var sequence: SequenceAction?
        var completed = false
        do {
            let group = Kinieta.group(member, other) { completed = true }
            sequence = group.mainSequence
            frames.step(0.5)  // `other` finishes; `member` is halfway
            group.pause()
        }
        // The engine takes `member` over, still paused, then drops the group.
        while sequence != nil { await Task.yield() }
        #expect(member.isPaused && other.state == .finished)
        #expect(!frames.isRunning)
        member.resume()
        frames.step(0.25)
        #expect(approx(view.frame.origin.x, 75, 0.5))
        frames.step(0.25)
        #expect(member.state == .finished && !completed)
        #expect(approx(view.frame.origin.x, 100))
        await member.finished()
    }

    @Test(.timeLimit(.minutes(1)))
    func aMemberExtendedWhileItsGroupIsPausedRunsOnAfterTheGroupHandleIsReleased() async {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let member = view.animate(.x(100), duration: 0.5)
        weak var sequence: SequenceAction?
        do {
            let group = Kinieta.group(member, view.animate(.alpha(0.5), duration: 1))
            sequence = group.mainSequence
            frames.step(0.5)
            group.pause()
            member.animate(.x(0), duration: 0.5)  // rejoins the paused group, paused
            #expect(member.isPaused)
        }
        while sequence != nil { await Task.yield() }
        member.resume()
        frames.step(0.5)
        #expect(member.state == .finished)
        #expect(approx(view.frame.origin.x, 0))
    }

    @Test(.timeLimit(.minutes(1)))
    func aMemberRegroupedBeforeItsReleasedGroupIsHandedOverRunsOnce() async {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let member = view.animate(.x(100), duration: 1)
        weak var released: Action?
        do {
            let group = Kinieta.group(member)
            frames.step(0.5)
            released = group.mainSequence.currentAction
            group.pause()
        }
        // Before the engine takes it over, a new group does.
        let regrouped = Kinieta.group(member)
        frames.step(0.5)  // paused: nothing moves, and the engine drops the released group
        while released != nil { await Task.yield() }  // held until the engine has had its chance to take it
        member.resume()
        frames.step(0.25)
        #expect(approx(view.frame.origin.x, 75, 0.5))  // driven once per frame
        frames.step(0.25)
        #expect(member.state == .finished && regrouped.state == .finished)
    }

    @Test(.timeLimit(.minutes(1)))
    func aMemberBehindAReleasedGroupsInfiniteDelayWaitsUntilCancelled() async {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let member = view.animate(.x(100), duration: 1)
        weak var sequence: SequenceAction?
        do {
            let group = Kinieta.group(member).delay(.infinity)
            sequence = group.mainSequence
        }
        frames.step(0.5)
        #expect(!frames.isRunning)
        // Nothing can end the group's wait, so the engine drops the group...
        while sequence != nil { await Task.yield() }
        // ...and the member it never started waits with it, as `wait(.infinity)` does.
        frames.step(1)
        #expect(member.isRunning && !frames.isRunning)
        #expect(approx(view.frame.origin.x, 0))
        member.cancel()
        #expect(member.state == .cancelled)
        await member.finished()
    }

    @Test func aRunningGroupWhoseHandleIsReleasedKeepsDrivingItsMembers() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let member = view.animate(.x(100), duration: 1)
        var completed = false
        Kinieta.group(member) { completed = true }  // the handle is released at once
        frames.step(0.5)
        member.pause()
        member.resume()
        frames.step(0.5)
        #expect(member.state == .finished && completed)
        #expect(approx(view.frame.origin.x, 100))
    }

    // MARK: Smoke test on the real display link

    @Test(.timeLimit(.minutes(1)))
    func realDisplayLinkRunsATimelineToCompletion() async {
        #expect(Engine.shared.driver is Engine.DisplayLinkDriver)
        let view = makeView()
        var completed = false
        let handle = view.animate(.x(100), duration: 0.2).onComplete { completed = true }
        #expect(handle.isRunning)
        await handle.finished()
        #expect(handle.state == .finished)
        #expect(completed)
        #expect(approx(view.frame.origin.x, 100))
        #expect(!Engine.shared.driver.isRunning)
    }
}

/// Reaches the deprecated `then` property through a protocol witness, so
/// testing it does not warn.
@MainActor
private protocol DeprecatedThen {
    var then: Kinieta { get }
}
extension DeprecatedThen {
    var deprecatedThen: Kinieta { then }
}
extension Kinieta: DeprecatedThen {}

/// Reaches the deprecated `Easing.Curve.custom` case through a protocol
/// witness, so testing it does not warn.
private protocol DeprecatedCustomCurve {
    static func custom(_ bezier: Bezier) -> Self
}
extension DeprecatedCustomCurve {
    static func deprecatedCustom(_ bezier: Bezier) -> Self { custom(bezier) }
}
extension Easing.Curve: DeprecatedCustomCurve {}

/// Reaches the deprecated `Bezier.solve(_:)` and `Bezier.Point.init(_:_:)`
/// through protocol witnesses, so testing them does not warn.
private protocol DeprecatedBezierSolve {
    func solve(_ x: Double) -> Double
}
extension DeprecatedBezierSolve {
    func deprecatedSolve(_ x: Double) -> Double { solve(x) }
}
extension Bezier: DeprecatedBezierSolve {}

private protocol DeprecatedPointInit {
    init(_ x: Double, _ y: Double)
}
extension DeprecatedPointInit {
    static func deprecatedInit(_ x: Double, _ y: Double) -> Self { Self(x, y) }
}
extension Bezier.Point: DeprecatedPointInit {}

func approx<T: BinaryFloatingPoint>(_ a: T, _ b: T, _ tolerance: T = 1e-6) -> Bool {
    abs(a - b) <= tolerance
}
#endif
