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
/// Serialized because every test shares `Engine.shared` and its frame driver.
@Suite(.serialized)
@MainActor
struct EngineTests {

    private func frame(_ dt: TimeInterval) -> Engine.Frame {
        Engine.Frame(dt)
    }

    private func makeView() -> UIView {
        UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
    }

    private func animation(
        _ view: UIView, _ properties: [Property], duration: TimeInterval,
        easing: Easing? = nil, completion: Block? = nil
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
            (.inOut(.sine), "sineInOut", { t in 0.5 - cos(.pi * t) / 2 }),
            (.inOut(.quad), "quadInOut", { t in t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2 }),
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
            let y = curve.solve(Double(i) / 20)
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
        defer { Engine.shared.isReduceMotionEnabled = { UIAccessibility.isReduceMotionEnabled } }
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
        #expect(approx(view.backgroundColor!.hsba.hue, 2.0 / 3.0, 0.01))  // blue's hue, not a sweep from 0
    }

    @Test func fadingFromClearKeepsTheTargetColour() {
        let view = makeView()
        view.backgroundColor = .clear
        let a = animation(view, [.background(.white, interpolation: .rgb)], duration: 1.0)
        _ = a.update(frame(0.5))
        let mid = rgb(view.backgroundColor)
        #expect(approx(mid.c1, 1, 1e-6) && approx(mid.c2, 1, 1e-6) && approx(mid.c3, 1, 1e-6))
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
            .then
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
        let handle = makeView().animate(.x(100), duration: 1)
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

    @Test func timelineFinishesOnItsOwnWhenTheViewIsReleased() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        var view: UIView? = makeView()
        let handle = view!.animate(.x(100), duration: 10)
        frames.step()
        #expect(handle.view != nil && handle.isRunning)
        view = nil
        frames.step()
        #expect(handle.view == nil)
        #expect(handle.state == .finished)
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
        let handle = makeView().wait(.nan)
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

func approx<T: BinaryFloatingPoint>(_ a: T, _ b: T, _ tolerance: T = 1e-6) -> Bool {
    abs(a - b) <= tolerance
}
#endif
