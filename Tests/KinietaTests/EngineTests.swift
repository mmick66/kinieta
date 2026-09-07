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

    @Test func easingSolvesByTimeNotByCurveParameter() {
        // For a cubic-bezier easing, y must be evaluated at x = t. At the
        // parameter t = 0.5 the reference cubicIn (0.55, 0.055, 0.675, 0.19)
        // has x ≈ 0.61, so indexing by parameter returns y(0.61) instead of y(0.5).
        // easings.net reference: easeInCubic(0.5) = 0.125.
        withKnownIssue("Bezier.solve indexes by parameter t instead of x. Fixed in Phase 3.") {
            let cubicIn = Easing.Get(.Cubic, "In")!
            #expect(approx(cubicIn.solve(0.5), 0.125, 0.02))
        }
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
        withKnownIssue("The cornerRadius case interpolates layer.borderWidth. Fixed in Phase 3.") {
            let view = makeView()
            let animation = Animation(view, moves: ["cornerRadius": 5], duration: 1.0, easing: nil, complete: nil)
            _ = animation.update(frame(1.0))
            #expect(approx(view.layer.cornerRadius, 5))
        }
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
        withKnownIssue("HLC-assisted interpolation stops at spectrum stop 4 of 5. Fixed in Phase 3.") {
            let view = makeView()
            let from = UIColor(red: 1.00, green: 0.44, blue: 0.75, alpha: 1.00)
            let to   = UIColor(red: 0.00, green: 1.00, blue: 1.00, alpha: 1.00)
            view.backgroundColor = from
            Defaults.ColorInterpolation.Method = .RGB_HLC_Assisted
            defer { Defaults.ColorInterpolation.Method = .Pure(space: .RGB) }
            let animation = Animation(view, moves: ["bg": to], duration: 1.0, easing: nil, complete: nil)
            _ = animation.update(frame(1.0))
            let got = view.backgroundColor!.components(as: .RGB)
            let want = to.components(as: .RGB)
            #expect(approx(got.c1, want.c1, 0.02))
            #expect(approx(got.c2, want.c2, 0.02))
            #expect(approx(got.c3, want.c3, 0.02))
        }
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

    @Test func sequenceFiresItsOwnCompletion() {
        withKnownIssue("Sequence returns .Finished without calling its complete block. Fixed in Phase 3.") {
            var completed = false
            let sequence = Sequence([.Pause(0.5, nil)], complete: { completed = true })
            #expect(sequence.update(frame(1.0)) == .Finished)
            #expect(completed)
        }
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
