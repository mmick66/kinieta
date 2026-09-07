import XCTest
@testable import Kinieta

/// Characterization tests for the engine.
///
/// Actions are driven with synthetic `Engine.Frame` values so no display link is
/// involved. Behaviour that is known to be wrong is pinned with
/// `XCTExpectFailure`; those tests flip green when the bug is fixed.
final class KinietaTests: XCTestCase {

    private func frame(_ dt: TimeInterval) -> Engine.Frame {
        return Engine.Frame(0, dt)
    }

    private func makeView() -> UIView {
        return UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
    }

    // MARK: Bezier & easing

    func testLinearBezierEndpointsAndMidpoint() {
        let linear = Easing.Linear
        XCTAssertEqual(linear.solve(0.0), 0.0, accuracy: 1e-9)
        XCTAssertEqual(linear.solve(0.5), 0.5, accuracy: 1e-3)
        XCTAssertEqual(linear.solve(1.0), 1.0, accuracy: 1e-9)
    }

    func testEveryPresetResolvesForEveryPlacement() {
        let types: [Easing.Types] = [.Sine, .Quad, .Cubic, .Quart, .Quint, .Expo, .Back]
        for type in types {
            for place in ["In", "Out", "InOut"] {
                XCTAssertNotNil(Easing.Get(type, place), "\(type.string)\(place) missing")
            }
        }
    }

    func testCustomEasingReturnsTheGivenCurve() {
        let custom = Bezier(0.16, 0.73, 0.89, 0.24)
        let resolved = Easing.Get(.Custom(custom), "InOut")
        XCTAssertEqual(resolved?.P1.x, 0.16)
        XCTAssertEqual(resolved?.P2.y, 0.24)
    }

    func testPresetCurvesPassThroughUnitEndpoints() {
        for place in ["In", "Out", "InOut"] {
            let curve = Easing.Get(.Cubic, place)!
            XCTAssertEqual(curve.solve(0.0), 0.0, accuracy: 1e-9)
            XCTAssertEqual(curve.solve(1.0), 1.0, accuracy: 1e-9)
        }
    }

    func testEasingSolvesByTimeNotByCurveParameter() {
        // For a cubic-bezier easing, y(x) must be evaluated at x = t. At the
        // parameter t = 0.5 the reference cubicIn (0.55, 0.055, 0.675, 0.19)
        // has x ≈ 0.61, so indexing by parameter returns y(0.61) instead of y(0.5).
        // easings.net reference: easeInCubic(0.5) = 0.125.
        XCTExpectFailure("Known bug: Bezier.solve indexes by parameter t instead of x. Fixed in Phase 3.")
        let cubicIn = Easing.Get(.Cubic, "In")!
        XCTAssertEqual(cubicIn.solve(0.5), 0.125, accuracy: 0.02)
    }

    // MARK: Pause

    func testPauseRunsForItsDurationThenCompletesOnce() {
        var completions = 0
        let pause = Pause(1.0, complete: { completions += 1 })
        XCTAssertEqual(pause.update(frame(0.25)), .Running)
        XCTAssertEqual(pause.update(frame(0.25)), .Running)
        XCTAssertEqual(pause.update(frame(0.25)), .Running)
        XCTAssertEqual(pause.update(frame(0.25)), .Finished)
        XCTAssertEqual(completions, 1)
    }

    func testZeroDurationPauseFinishesImmediately() {
        let pause = Pause(0.0, complete: nil)
        XCTAssertEqual(pause.update(frame(0.016)), .Finished)
    }

    // MARK: Animation

    func testLinearAnimationInterpolatesFrameOriginAndCompletes() {
        let view = makeView()
        var completed = false
        let animation = Animation(view, moves: ["x": 100], duration: 1.0, easing: nil, complete: { completed = true })

        XCTAssertEqual(animation.update(frame(0.5)), .Running)
        XCTAssertEqual(view.frame.origin.x, 50, accuracy: 0.5)
        XCTAssertFalse(completed)

        XCTAssertEqual(animation.update(frame(0.5)), .Finished)
        XCTAssertEqual(view.frame.origin.x, 100, accuracy: 1e-6)
        XCTAssertTrue(completed)
    }

    func testOvershootingFramesClampToTheEndValue() {
        let view = makeView()
        let animation = Animation(view, moves: ["y": 80], duration: 0.5, easing: nil, complete: nil)
        XCTAssertEqual(animation.update(frame(2.0)), .Finished)
        XCTAssertEqual(view.frame.origin.y, 80, accuracy: 1e-6)
    }

    func testZeroDurationAnimationSnaps() {
        let view = makeView()
        let animation = Animation(view, moves: ["x": 42, "a": 0.5], duration: 0.0, easing: nil, complete: nil)
        XCTAssertEqual(animation.update(frame(0.016)), .Finished)
        XCTAssertEqual(view.frame.origin.x, 42)
        XCTAssertEqual(view.alpha, 0.5, accuracy: 1e-6)
    }

    func testAllNumericPropertiesAreAnimatable() {
        let view = makeView()
        let target = CGFloat(30)
        let moves: [String: Any] = ["x": target, "y": target, "w": target, "h": target, "a": 0.3, "brw": target]
        let animation = Animation(view, moves: moves, duration: 1.0, easing: nil, complete: nil)
        _ = animation.update(frame(1.0))
        XCTAssertEqual(view.frame, CGRect(x: 30, y: 30, width: 30, height: 30))
        XCTAssertEqual(view.alpha, 0.3, accuracy: 1e-6)
        XCTAssertEqual(view.layer.borderWidth, 30, accuracy: 1e-6)
    }

    func testRotationIsAnimatedInDegrees() {
        // Rotation is tested on its own: a rotated view's frame is its bounding box.
        let view = makeView()
        let animation = Animation(view, moves: ["r": 45], duration: 1.0, easing: nil, complete: nil)
        _ = animation.update(frame(0.5))
        XCTAssertEqual(view.rotation, 22.5, accuracy: 0.1)
        _ = animation.update(frame(0.5))
        XCTAssertEqual(view.rotation, 45, accuracy: 1e-4)
    }

    func testVerboseKeyWinsOverAbbreviation() {
        let view = makeView()
        let animation = Animation(view, moves: ["w": 20, "width": 60], duration: 1.0, easing: nil, complete: nil)
        _ = animation.update(frame(1.0))
        XCTAssertEqual(view.frame.size.width, 60)
    }

    func testCornerRadiusIsAnimated() {
        XCTExpectFailure("Known bug: the cornerRadius case interpolates layer.borderWidth. Fixed in Phase 3.")
        let view = makeView()
        let animation = Animation(view, moves: ["cornerRadius": 5], duration: 1.0, easing: nil, complete: nil)
        _ = animation.update(frame(1.0))
        XCTAssertEqual(view.layer.cornerRadius, 5, accuracy: 1e-6)
    }

    func testBackgroundColourReachesTargetInPureRGB() {
        let view = makeView()
        view.backgroundColor = .red
        Defaults.ColorInterpolation.Method = .Pure(space: .RGB)
        let animation = Animation(view, moves: ["bg": UIColor.blue], duration: 1.0, easing: nil, complete: nil)
        _ = animation.update(frame(1.0))
        XCTAssertEqual(view.backgroundColor!.components(as: .RGB), UIColor.blue.components(as: .RGB))
    }

    func testBackgroundColourReachesTargetInHCLAssistedMode() {
        XCTExpectFailure("Known bug: HLC-assisted interpolation stops at spectrum stop 4 of 5. Fixed in Phase 3.")
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
        XCTAssertEqual(got.c1, want.c1, accuracy: 0.02)
        XCTAssertEqual(got.c2, want.c2, accuracy: 0.02)
        XCTAssertEqual(got.c3, want.c3, accuracy: 0.02)
    }

    // MARK: Sequence & Group

    func testSequenceRunsChildrenInOrder() {
        let view = makeView()
        let sequence = Sequence([
            .Pause(1.0, nil),
            .Animation(view, ["x": 100], 1.0, nil, nil)
        ], complete: nil)

        XCTAssertEqual(sequence.update(frame(0.5)), .Running)
        XCTAssertEqual(view.frame.origin.x, 0, "animation must not start during the pause")
        XCTAssertEqual(sequence.update(frame(0.5)), .Running)   // pause ends
        XCTAssertEqual(sequence.update(frame(0.5)), .Running)   // animation half way
        XCTAssertEqual(view.frame.origin.x, 50, accuracy: 0.5)
        XCTAssertEqual(sequence.update(frame(0.5)), .Finished)
        XCTAssertEqual(view.frame.origin.x, 100, accuracy: 1e-6)
    }

    func testSequenceFiresItsOwnCompletion() {
        XCTExpectFailure("Known bug: Sequence returns .Finished without calling its complete block. Fixed in Phase 3.")
        var completed = false
        let sequence = Sequence([.Pause(0.5, nil)], complete: { completed = true })
        XCTAssertEqual(sequence.update(frame(1.0)), .Finished)
        XCTAssertTrue(completed)
    }

    func testGroupFinishesWhenTheLongestChildFinishes() {
        let a = makeView(), b = makeView()
        var completed = false
        let group = Group([
            .Animation(a, ["x": 100], 0.5, nil, nil),
            .Animation(b, ["x": 100], 1.0, nil, nil)
        ], complete: { completed = true })

        XCTAssertEqual(group.update(frame(0.5)), .Running)
        XCTAssertEqual(a.frame.origin.x, 100, accuracy: 1e-6)
        XCTAssertEqual(b.frame.origin.x, 50, accuracy: 0.5)
        XCTAssertFalse(completed)

        XCTAssertEqual(group.update(frame(0.5)), .Finished)
        XCTAssertEqual(b.frame.origin.x, 100, accuracy: 1e-6)
        XCTAssertTrue(completed)
    }

    // MARK: Kinieta chain building

    private func descriptions(_ k: Kinieta) -> [String] {
        return k.mainSequence.types.map { $0.description }
    }

    func testMoveAppendsAnAnimation() {
        let k = Kinieta(for: makeView()).move(to: ["x": 1], during: 1)
        XCTAssertEqual(descriptions(k), ["Animation (x:1)"])
    }

    func testDelayWrapsTheLastActionInASequenceWithAPause() {
        let k = Kinieta(for: makeView()).move(to: ["x": 1], during: 1).delay(for: 0.5)
        XCTAssertEqual(descriptions(k), ["Sequence (2)"])
        guard case .Sequence(let inner, _)? = k.mainSequence.types.first else { return XCTFail() }
        XCTAssertEqual(inner.map { $0.description }, ["Pause (0.5)", "Animation (x:1)"])
    }

    func testParallelGroupsAllUngroupedActions() {
        let k = Kinieta(for: makeView())
            .move(to: ["x": 1], during: 1)
            .move(to: ["a": 0], during: 1)
            .parallel()
        XCTAssertEqual(descriptions(k), ["Group (2)"])
    }

    func testThenSealsPrecedingActionsSoParallelOnlyTakesLaterOnes() {
        let k = Kinieta(for: makeView())
            .move(to: ["x": 1], during: 1)
            .then
            .move(to: ["x": 2], during: 1)
            .move(to: ["a": 0], during: 1)
            .parallel()
        XCTAssertEqual(descriptions(k), ["Group (1)", "Group (2)"])
    }

    func testAgainRepeatsTheWholeChain() {
        let k = Kinieta(for: makeView())
            .move(to: ["x": 1], during: 1)
            .wait(for: 1)
            .again(times: 2)
        XCTAssertEqual(descriptions(k), ["Animation (x:1)", "Pause (1.0)", "Animation (x:1)", "Pause (1.0)", "Animation (x:1)", "Pause (1.0)"])
    }

    func testEasingAttachesToTheLastAnimationOnly() {
        let k = Kinieta(for: makeView()).move(to: ["x": 1], during: 1).easeInOut(.Back)
        guard case .Animation(_, _, _, let bezier?, _)? = k.mainSequence.types.first else { return XCTFail("no easing attached") }
        XCTAssertEqual(bezier.P1.x, 0.68)
        XCTAssertEqual(bezier.P2.y, 1.55)
    }

    func testCompleteAttachesToTheLastAction() {
        let k = Kinieta(for: makeView()).move(to: ["x": 1], during: 1).wait(for: 1).complete { }
        guard case .Pause(_, let block)? = k.mainSequence.types.last else { return XCTFail() }
        XCTAssertNotNil(block)
    }

    // MARK: End to end through the display link

    func testEngineDrivesAnAnimationToCompletionOnTheMainRunLoop() {
        let view = makeView()
        let done = expectation(description: "animation completes")
        view.move(to: ["x": 100], during: 0.2).complete { done.fulfill() }
        wait(for: [done], timeout: 3.0)
        XCTAssertEqual(view.frame.origin.x, 100, accuracy: 1e-6)
    }
}
