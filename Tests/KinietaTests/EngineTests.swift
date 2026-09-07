import Testing
import UIKit
@testable import Kinieta

/// Characterization tests for the engine.
///
/// Actions are driven with synthetic `Engine.Frame` values so no display link is
/// involved. Behaviour that is known to be wrong is pinned with `withKnownIssue`;
/// those tests flip when the bug is fixed and the known-issue marker is removed.
@MainActor
struct EngineTests {

    private func frame(_ dt: TimeInterval) -> Engine.Frame {
        Engine.Frame(0, dt)
    }

    private func makeView() -> UIView {
        UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
    }

    // MARK: Bezier & easing

    @Test func linearBezierEndpointsAndMidpoint() {
        let linear = Easing.Linear
        #expect(linear.solve(0.0) == 0.0)
        #expect(approx(linear.solve(0.5), 0.5, 1e-3))
        #expect(linear.solve(1.0) == 1.0)
    }

    @Test func everyPresetResolvesForEveryPlacement() {
        let types: [Easing.Types] = [.Sine, .Quad, .Cubic, .Quart, .Quint, .Expo, .Back]
        for type in types {
            for place in ["In", "Out", "InOut"] {
                #expect(Easing.Get(type, place) != nil, "\(type.string)\(place) missing")
            }
        }
    }

    @Test func customEasingReturnsTheGivenCurve() {
        let custom = Bezier(0.16, 0.73, 0.89, 0.24)
        let resolved = Easing.Get(.Custom(custom), "InOut")
        #expect(resolved?.P1.x == 0.16)
        #expect(resolved?.P2.y == 0.24)
    }

    @Test func presetCurvesPassThroughUnitEndpoints() {
        for place in ["In", "Out", "InOut"] {
            let curve = Easing.Get(.Cubic, place)!
            #expect(curve.solve(0.0) == 0.0)
            #expect(curve.solve(1.0) == 1.0)
        }
    }

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

    @Test func easingSolvesByTimeNotByCurveParameter() {
        // For a cubic-bezier easing, y must be evaluated at x = t, not at the
        // curve parameter t. Independently evaluated: cubicIn(0.5) = 0.1453,
        // whereas indexing by parameter gave 0.2169.
        let cubicIn = Easing.Get(.Cubic, "In")!
        #expect(approx(cubicIn.solve(0.5), 0.1453, 0.001))
    }

    @Test func tableSolverMatchesExactBezierEvaluation() {
        let curves = [(0.55, 0.055, 0.675, 0.19), (0.68, -0.55, 0.265, 1.55), (0.16, 0.73, 0.89, 0.24), (1.0, 0.0, 0.0, 1.0)]
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
        let reference: [(Easing.Types, String, (Double) -> Double)] = [
            (.Quad,  "In",    { t in t * t }),
            (.Quad,  "Out",   { t in 1 - (1 - t) * (1 - t) }),
            (.Cubic, "In",    { t in t * t * t }),
            (.Cubic, "Out",   { t in 1 - pow(1 - t, 3) }),
            (.Cubic, "InOut", { t in t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2 }),
            (.Quart, "In",    { t in t * t * t * t }),
            (.Expo,  "In",    { t in pow(2, 10 * t - 10) }),
            (.Sine,  "In",    { t in 1 - cos(t * .pi / 2) }),
            (.Back,  "In",    { t in c3 * t * t * t - c1 * t * t }),
        ]
        for (type, place, function) in reference {
            let curve = Easing.Get(type, place)!
            for t in [0.25, 0.5, 0.75] {
                #expect(approx(curve.solve(t), function(t), 0.06), "\(type.string)\(place) at \(t)")
            }
        }
    }

    @Test func solveClampsTimeOutsideTheUnitInterval() {
        let curve = Easing.Get(.Back, "InOut")!
        #expect(curve.solve(-0.5) == 0)
        #expect(curve.solve(1.5) == 1)
        // backInOut dips below 0 early and overshoots 1 late.
        #expect(curve.solve(0.1) < 0)
        #expect(curve.solve(0.9) > 1)
    }

    // MARK: Frame clock

    @Test func frameClockAdvancesByRealElapsedTime() {
        var clock = Engine.FrameClock()
        #expect(clock.frame(at: 10.000, nominalDuration: 1.0 / 60).duration == 1.0 / 60)   // first frame: nominal
        #expect(approx(clock.frame(at: 10.020, nominalDuration: 1.0 / 60).duration, 0.020))
        #expect(approx(clock.frame(at: 10.100, nominalDuration: 1.0 / 60).duration, 0.080))  // dropped frames catch up
        #expect(approx(clock.frame(at: 10.108, nominalDuration: 1.0 / 120).duration, 0.008)) // ProMotion frame
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
        #expect(pause.update(frame(0.25)) == .Running)
        #expect(pause.update(frame(0.25)) == .Running)
        #expect(pause.update(frame(0.25)) == .Running)
        #expect(pause.update(frame(0.25)) == .Finished)
        #expect(completions == 1)
    }

    @Test func zeroDurationPauseFinishesImmediately() {
        let pause = Pause(0.0, complete: nil)
        #expect(pause.update(frame(0.016)) == .Finished)
    }

    // MARK: Animation

    @Test func linearAnimationInterpolatesFrameOriginAndCompletes() {
        let view = makeView()
        var completed = false
        let animation = Animation(view, moves: ["x": 100], duration: 1.0, easing: nil, complete: { completed = true })

        #expect(animation.update(frame(0.5)) == .Running)
        #expect(approx(view.frame.origin.x, 50, 0.5))
        #expect(!completed)

        #expect(animation.update(frame(0.5)) == .Finished)
        #expect(approx(view.frame.origin.x, 100))
        #expect(completed)
    }

    @Test func overshootingFramesClampToTheEndValue() {
        let view = makeView()
        let animation = Animation(view, moves: ["y": 80], duration: 0.5, easing: nil, complete: nil)
        #expect(animation.update(frame(2.0)) == .Finished)
        #expect(approx(view.frame.origin.y, 80))
    }

    @Test func zeroDurationAnimationSnaps() {
        let view = makeView()
        let animation = Animation(view, moves: ["x": 42, "a": 0.5], duration: 0.0, easing: nil, complete: nil)
        #expect(animation.update(frame(0.016)) == .Finished)
        #expect(view.frame.origin.x == 42)
        #expect(approx(view.alpha, 0.5))
    }

    @Test func allNumericPropertiesAreAnimatable() {
        let view = makeView()
        let target = CGFloat(30)
        let moves: [String: Any] = ["x": target, "y": target, "w": target, "h": target, "a": 0.3, "brw": target]
        let animation = Animation(view, moves: moves, duration: 1.0, easing: nil, complete: nil)
        _ = animation.update(frame(1.0))
        #expect(view.frame == CGRect(x: 30, y: 30, width: 30, height: 30))
        #expect(approx(view.alpha, 0.3))
        #expect(approx(view.layer.borderWidth, 30))
    }

    @Test func rotationIsAnimatedInDegrees() {
        // Rotation is tested on its own: a rotated view's frame is its bounding box.
        let view = makeView()
        let animation = Animation(view, moves: ["r": 45], duration: 1.0, easing: nil, complete: nil)
        _ = animation.update(frame(0.5))
        #expect(approx(view.rotation, 22.5, 0.1))
        _ = animation.update(frame(0.5))
        #expect(approx(view.rotation, 45, 1e-4))
    }

    @Test func verboseKeyWinsOverAbbreviation() {
        let view = makeView()
        let animation = Animation(view, moves: ["w": 20, "width": 60], duration: 1.0, easing: nil, complete: nil)
        _ = animation.update(frame(1.0))
        #expect(view.frame.size.width == 60)
    }

    @Test func cornerRadiusIsAnimated() {
        let view = makeView()
        let animation = Animation(view, moves: ["cornerRadius": 5], duration: 1.0, easing: nil, complete: nil)
        _ = animation.update(frame(0.5))
        #expect(approx(view.layer.cornerRadius, 2.5, 0.05))
        #expect(view.layer.borderWidth == 0)
        _ = animation.update(frame(0.5))
        #expect(approx(view.layer.cornerRadius, 5))
    }

    @Test func reduceMotionSnapsAnimationsButKeepsPauses() {
        Engine.shared.isReduceMotionEnabled = { true }
        defer { Engine.shared.isReduceMotionEnabled = { UIAccessibility.isReduceMotionEnabled } }
        let view = makeView()
        let animation = Animation(view, moves: ["x": 100], duration: 1.0, easing: nil, complete: nil)
        #expect(animation.update(frame(0.016)) == .Finished)
        #expect(view.frame.origin.x == 100)
        let pause = Pause(1.0, complete: nil)
        #expect(pause.update(frame(0.5)) == .Running)

        Engine.shared.respectsReduceMotion = false
        defer { Engine.shared.respectsReduceMotion = true }
        let forced = Animation(makeView(), moves: ["x": 100], duration: 1.0, easing: nil, complete: nil)
        #expect(forced.update(frame(0.5)) == .Running)
    }

    @Test func backgroundColourReachesTargetInPureRGB() {
        let view = makeView()
        view.backgroundColor = .red
        Defaults.ColorInterpolation.Method = .Pure(space: .RGB)
        let animation = Animation(view, moves: ["bg": UIColor.blue], duration: 1.0, easing: nil, complete: nil)
        _ = animation.update(frame(1.0))
        #expect(view.backgroundColor!.components(as: .RGB) == UIColor.blue.components(as: .RGB))
    }

    @Test func backgroundColourReachesTargetInHCLAssistedMode() {
        let view = makeView()
        let from = UIColor(red: 1.00, green: 0.44, blue: 0.75, alpha: 1.00)
        let to   = UIColor(red: 0.00, green: 1.00, blue: 1.00, alpha: 1.00)
        view.backgroundColor = from
        Defaults.ColorInterpolation.Method = .RGB_HLC_Assisted
        defer { Defaults.ColorInterpolation.Method = .Pure(space: .RGB) }
        let animation = Animation(view, moves: ["bg": to], duration: 1.0, easing: nil, complete: nil)
        _ = animation.update(frame(0.5))
        let mid = view.backgroundColor!.components(as: .RGB)
        #expect(mid.c1 > 0.05 && mid.c1 < 0.95, "half way must be neither endpoint")
        _ = animation.update(frame(0.5))
        let got = view.backgroundColor!.components(as: .RGB)
        let want = to.components(as: .RGB)
        #expect(approx(got.c1, want.c1, 0.01))
        #expect(approx(got.c2, want.c2, 0.01))
        #expect(approx(got.c3, want.c3, 0.01))
    }

    @Test func overshootingEasingDoesNotBreakColourInterpolation() {
        let view = makeView()
        view.backgroundColor = .red
        Defaults.ColorInterpolation.Method = .RGB_HLC_Assisted
        defer { Defaults.ColorInterpolation.Method = .Pure(space: .RGB) }
        let back = Easing.Get(.Back, "InOut")
        let animation = Animation(view, moves: ["bg": UIColor.blue], duration: 1.0, easing: back, complete: nil)
        for _ in 0..<10 { _ = animation.update(frame(0.1)) }
        let got = view.backgroundColor!.components(as: .RGB)
        #expect(approx(got.c1, 0, 0.01) && approx(got.c3, 1, 0.01))
    }

    @Test func hclSpectrumStartsAndEndsOnTheEndpoints() {
        let from = UIColor(red: 0.9, green: 0.2, blue: 0.1, alpha: 1)
        let to   = UIColor(red: 0.1, green: 0.3, blue: 0.9, alpha: 1)
        let stops = from.spectrumComponentsHLC5(to: to)
        #expect(stops.count == 6)
        let first = stops.first!.components(as: .RGB), last = stops.last!.components(as: .RGB)
        let f = from.components(as: .RGB), t = to.components(as: .RGB)
        #expect(approx(first.c1, f.c1, 1e-3) && approx(first.c2, f.c2, 1e-3) && approx(first.c3, f.c3, 1e-3))
        #expect(approx(last.c1, t.c1, 1e-3) && approx(last.c2, t.c2, 1e-3) && approx(last.c3, t.c3, 1e-3))
    }

    // MARK: Sequence & Group

    @Test func sequenceRunsChildrenInOrder() {
        let view = makeView()
        let sequence = Sequence([
            .Pause(1.0, nil),
            .Animation(view, ["x": 100], 1.0, nil, nil)
        ], complete: nil)

        #expect(sequence.update(frame(0.5)) == .Running)
        #expect(view.frame.origin.x == 0, "animation must not start during the pause")
        #expect(sequence.update(frame(0.5)) == .Running)   // pause ends
        #expect(sequence.update(frame(0.5)) == .Running)   // animation half way
        #expect(approx(view.frame.origin.x, 50, 0.5))
        #expect(sequence.update(frame(0.5)) == .Finished)
        #expect(approx(view.frame.origin.x, 100))
    }

    @Test func sequenceFiresItsOwnCompletionExactlyOnce() {
        var completions = 0
        let sequence = Sequence([.Pause(0.5, nil), .Pause(0.5, nil)], complete: { completions += 1 })
        #expect(sequence.update(frame(0.6)) == .Running)
        #expect(completions == 0)
        #expect(sequence.update(frame(0.6)) == .Finished)
        #expect(completions == 1)
    }

    @Test func groupFinishesWhenTheLongestChildFinishes() {
        let a = makeView(), b = makeView()
        var completed = false
        let group = Group([
            .Animation(a, ["x": 100], 0.5, nil, nil),
            .Animation(b, ["x": 100], 1.0, nil, nil)
        ], complete: { completed = true })

        #expect(group.update(frame(0.5)) == .Running)
        #expect(approx(a.frame.origin.x, 100))
        #expect(approx(b.frame.origin.x, 50, 0.5))
        #expect(!completed)

        #expect(group.update(frame(0.5)) == .Finished)
        #expect(approx(b.frame.origin.x, 100))
        #expect(completed)
    }

    // MARK: Kinieta chain building

    private func descriptions(_ k: Kinieta) -> [String] {
        k.mainSequence.types.map { $0.description }
    }

    @Test func moveAppendsAnAnimation() {
        let k = Kinieta(for: makeView()).move(to: ["x": 1], during: 1)
        #expect(descriptions(k) == ["Animation (x:1)"])
    }

    @Test func delayWrapsTheLastActionInASequenceWithAPause() throws {
        let k = Kinieta(for: makeView()).move(to: ["x": 1], during: 1).delay(for: 0.5)
        #expect(descriptions(k) == ["Sequence (2)"])
        guard case .Sequence(let inner, _)? = k.mainSequence.types.first else {
            Issue.record("expected a Sequence"); return
        }
        #expect(inner.map { $0.description } == ["Pause (0.5)", "Animation (x:1)"])
    }

    @Test func parallelGroupsAllUngroupedActions() {
        let k = Kinieta(for: makeView())
            .move(to: ["x": 1], during: 1)
            .move(to: ["a": 0], during: 1)
            .parallel()
        #expect(descriptions(k) == ["Group (2)"])
    }

    @Test func thenSealsPrecedingActionsSoParallelOnlyTakesLaterOnes() {
        let k = Kinieta(for: makeView())
            .move(to: ["x": 1], during: 1)
            .then
            .move(to: ["x": 2], during: 1)
            .move(to: ["a": 0], during: 1)
            .parallel()
        #expect(descriptions(k) == ["Group (1)", "Group (2)"])
    }

    @Test func againRepeatsTheWholeChain() {
        let k = Kinieta(for: makeView())
            .move(to: ["x": 1], during: 1)
            .wait(for: 1)
            .again(times: 2)
        #expect(descriptions(k) == ["Animation (x:1)", "Pause (1.0)", "Animation (x:1)", "Pause (1.0)", "Animation (x:1)", "Pause (1.0)"])
    }

    @Test func easingAttachesToTheLastAnimationOnly() {
        let k = Kinieta(for: makeView()).move(to: ["x": 1], during: 1).easeInOut(.Back)
        guard case .Animation(_, _, _, let bezier?, _)? = k.mainSequence.types.first else {
            Issue.record("no easing attached"); return
        }
        #expect(bezier.P1.x == 0.68)
        #expect(bezier.P2.y == 1.55)
    }

    @Test func completeAttachesToTheLastAction() {
        let k = Kinieta(for: makeView()).move(to: ["x": 1], during: 1).wait(for: 1).complete { }
        guard case .Pause(_, let block)? = k.mainSequence.types.last else {
            Issue.record("expected a Pause"); return
        }
        #expect(block != nil)
    }

    // MARK: End to end through the display link

    @Test(.timeLimit(.minutes(1)))
    func engineDrivesAnAnimationToCompletionOnTheMainRunLoop() async {
        let view = makeView()
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            view.move(to: ["x": 100], during: 0.2).complete { done.resume() }
        }
        #expect(approx(view.frame.origin.x, 100))
    }

    @Test(.timeLimit(.minutes(1)))
    func engineGroupsKinietaHandlesWithOneCompletion() async {
        let a = makeView(), b = makeView()
        var completions = 0
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            let moveA = a.move(to: ["x": 100], during: 0.1)
            let moveB = b.move(to: ["y": 100], during: 0.3)
            Engine.shared.group([moveA, moveB]) {
                completions += 1
                done.resume()
            }
        }
        #expect(completions == 1)
        #expect(approx(a.frame.origin.x, 100))
        #expect(approx(b.frame.origin.y, 100))
    }
}

func approx<T: BinaryFloatingPoint>(_ a: T, _ b: T, _ tolerance: T = 1e-6) -> Bool {
    abs(a - b) <= tolerance
}
