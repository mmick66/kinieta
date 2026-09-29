#if canImport(UIKit)
import Testing
import UIKit

@testable import Kinieta

// Types of this file's own that share Kinieta's names. They shadow the
// library's here, so everything below reaches Kinieta's through the class.
private struct Property {}
private struct Easing {}
private struct Engine {}
private struct Bezier {}

/// A module with its own `Property`, `Easing` or `Engine` spells Kinieta's as
/// `Kinieta.Property`, `Kinieta.Easing` and `Kinieta.Engine`.
@Suite(.serialized, .usesSharedEngine)
@MainActor
struct NamespaceTests {

    init() {
        Kinieta.Engine.shared.isReduceMotionEnabled = { false }
    }

    @Test func theLocalTypesShadowKinietas() {
        #expect(Property.self != Kinieta.Property.self)
        #expect(Easing.self != Kinieta.Easing.self)
        #expect(Engine.self != Kinieta.Engine.self)
        #expect(Bezier.self != Kinieta.Bezier.self)
    }

    @Test func kinietasTypesAnimateThroughTheClassName() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let properties: [Kinieta.Property] = [.alpha(0)]
        let easing: Kinieta.Easing = .custom(Kinieta.Bezier.linear)

        var completions = 0
        let completion: Kinieta.Completion = { completions += 1 }
        let view = UIView()
        view.animate(properties, duration: 1).easing(easing).onComplete(completion)
        frames.step(0.5)
        #expect(view.alpha == 0.5)
        frames.step(0.5)
        #expect(view.alpha == 0)
        #expect(completions == 1)
    }

    @Test func aGroupTakesAKinietaCompletion() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        var finished = false
        let completion: Kinieta.Completion = { finished = true }
        let view = UIView()
        Kinieta.group(view.animate(.alpha(0), duration: 1), completion: completion)
        frames.step(1)
        #expect(finished)
    }

    /// Before `Completion`, completion blocks were plain `() -> Void`, which
    /// cannot convert to it. Stored closures of that type still work.
    @Test func aStoredNonisolatedBlockIsStillAccepted() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let counter = Counter()
        let block: () -> Void = { counter.count += 1 }
        let optional: (() -> Void)? = block
        let views = [UIView(), UIView(), UIView(), UIView()]
        views[0].animate(.alpha(0), duration: 1).onComplete(block)
        Kinieta.group(views[1].animate(.alpha(0), duration: 1), completion: block)
        Kinieta.group([views[2].animate(.alpha(0), duration: 1)], completion: optional)
        Kinieta.group([views[3].animate(.alpha(0), duration: 1)], completion: nil)
        frames.step(1)
        #expect(counter.count == 3)
        #expect(views.allSatisfy { $0.alpha == 0 })
    }

    @Test func kinietasProtocolsAndSettingsAreReachableThroughTheClassName() {
        func halfway<Value: Kinieta.Interpolatable>(_ from: Value, _ to: Value) -> Value {
            from.interpolated(to: to, progress: 0.5)
        }
        #expect(halfway(CGFloat(0), 10) == 5)
        let interpolation: Kinieta.ColorInterpolation = Kinieta.Engine.shared.colorInterpolation
        #expect(interpolation == Kinieta.Engine.shared.colorInterpolation)
        let behavior: Kinieta.ReduceMotionBehavior = Kinieta.Engine.shared.reduceMotionBehavior
        #expect(behavior == Kinieta.Engine.shared.reduceMotionBehavior)
        let custom: Kinieta.CustomProperty? = nil
        #expect(custom == nil)
    }
}

private final class Counter {
    var count = 0
}
#endif
