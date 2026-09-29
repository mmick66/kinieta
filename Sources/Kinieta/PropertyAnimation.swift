// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit)
import UIKit

/// Interpolates a set of properties on one view over a duration.
///
/// An animation owns the properties it writes. When a newer animation starts
/// on a property of the same view, from any timeline, it takes that property
/// over: this one stops writing it and keeps animating the rest. Its duration
/// and completion block are unchanged, so the timeline it belongs to keeps
/// its schedule even when every property has been taken.
@MainActor
final class PropertyAnimation: Action {

    /// One key of one property: what it writes, and whether Reduce Motion snaps it.
    private struct Channel {
        let slot: Slot
        let apply: Property.Transformation
        let snaps: Bool
    }

    private let target: ViewRef
    private var channels: [Channel] = []

    let easing: Bezier
    let duration: TimeInterval
    private var elapsed: TimeInterval = 0
    /// The factor written on the latest frame, and the one before it, which is
    /// what the view showed when the latest frame began. `nil` before the first.
    private var factor: CGFloat?
    private var previousFactor: CGFloat?
    private var appliedFrame: Int?

    let completion: Kinieta.Completion?

    init(_ spec: AnimationSpec) {
        self.target = spec.target
        self.easing = spec.easing ?? .linear
        self.completion = spec.completion

        // The last property listed for a key wins, so `.frame(…), .x(…)` takes
        // the position from `.x`. Order of first mention is kept.
        var order: [Property.Key] = []
        var latest: [Property.Key: Int] = [:]
        for (index, property) in spec.properties.enumerated() {
            for key in property.keys {
                if latest[key] == nil { order.append(key) }
                latest[key] = index
            }
        }
        let winners = spec.properties.indices.filter(Set(latest.values).contains)

        // Under Reduce Motion, an animation with nothing left to interpolate finishes on its first frame.
        let engine = Engine.shared
        let snaps = winners.map { engine.snapsUnderReduceMotion(spec.properties[$0]) }
        self.duration = engine.shouldSkipMotion && !snaps.contains(false) ? 0 : spec.duration

        guard let view = target.view else { return }

        // Take the keys over before reading the starting values, so an older
        // animation that already wrote this frame hands back what was on screen.
        var slots: [Property.Key: Slot] = [:]
        for key in order { slots[key] = Slot(object: spec.properties[latest[key]!].owner(on: view), key: key) }
        PropertyAnimation.owners.claim(order.map { slots[$0]! }, for: self)

        let mode = engine.colorInterpolation
        var built: [Property.Key: Channel] = [:]
        for (index, snaps) in zip(winners, snaps) {
            let property = spec.properties[index]
            let parts = property.transformations(for: view, defaultColorInterpolation: mode)
            for (key, apply) in zip(property.keys, parts) where latest[key] == index {
                built[key] = Channel(slot: slots[key]!, apply: apply, snaps: snaps)
            }
        }
        channels = order.compactMap { built[$0] }
    }

    func update(_ frame: Engine.Frame) -> ActionResult {
        // The view was deallocated: there is nothing left to animate.
        guard let view = target.view else {
            end()
            return .finished(overshoot: frame.duration)
        }

        guard duration > 0 else {
            apply(1.0, to: view)
            end()
            completion?()
            return .finished(overshoot: frame.duration)
        }

        let total = elapsed + frame.duration
        elapsed = min(total, duration)
        let progress = easing.solve(elapsed / duration)
        apply(CGFloat(progress), to: view)

        if elapsed >= duration {
            end()
            completion?()
            return .finished(overshoot: total - duration)
        }
        return .running
    }

    private func apply(_ factor: CGFloat, to view: UIView) {
        let frameNumber = Engine.shared.frameNumber
        if appliedFrame != frameNumber {
            previousFactor = self.factor
            appliedFrame = frameNumber
        }
        self.factor = factor
        for channel in channels {
            channel.apply(view, channel.snaps ? 1.0 : factor)
        }
    }

    /// Hands the keys this animation still owns back, so a later animation of
    /// them starts without an older owner to take them from.
    private func end() {
        PropertyAnimation.owners.release(channels.map(\.slot), of: self)
        channels = []
    }

    /// Stops writing `slot`, which a newer animation has taken over. If this
    /// animation has already written it during the current frame, the view is
    /// put back to what it showed when the frame began, where the newer one starts.
    fileprivate func surrender(_ slot: Slot) {
        guard let index = channels.firstIndex(where: { $0.slot == slot }) else { return }
        let channel = channels.remove(at: index)
        guard appliedFrame == Engine.shared.frameNumber, let view = target.view else { return }
        // Before the first frame the view showed the starting value.
        let shown = previousFactor.map { channel.snaps ? 1.0 : $0 } ?? 0
        channel.apply(view, shown)
    }
}

// MARK: - Ownership

extension PropertyAnimation {

    /// A key of one object: the view, or a constraint for `.constant`.
    struct Slot: Hashable {
        let object: ObjectIdentifier
        let key: Property.Key
    }

    /// Which animation owns each key. Owners are held weakly: an animation in a
    /// cancelled timeline is released without ending, and its entries are swept
    /// once the table has doubled since the last sweep.
    @MainActor
    final class Owners {
        private struct Owner {
            weak var animation: PropertyAnimation?
        }

        private var owners: [Slot: Owner] = [:]
        private var sweepThreshold = 64

        /// Gives `slots` to `animation`, taking each from its previous owner.
        func claim(_ slots: [Slot], for animation: PropertyAnimation) {
            for slot in slots {
                if let previous = owners[slot]?.animation, previous !== animation { previous.surrender(slot) }
                owners[slot] = Owner(animation: animation)
            }
            if owners.count > sweepThreshold {
                owners = owners.filter { $0.value.animation != nil }
                sweepThreshold = max(64, owners.count * 2)
            }
        }

        /// Frees the `slots` that `animation` still owns.
        func release(_ slots: [Slot], of animation: PropertyAnimation) {
            for slot in slots where owners[slot]?.animation === animation {
                owners[slot] = nil
            }
        }

        /// The animation that owns `key` of `object`, if any.
        func owner(of object: AnyObject, _ key: Property.Key) -> PropertyAnimation? {
            owners[Slot(object: ObjectIdentifier(object), key: key)]?.animation
        }
    }

    static let owners = Owners()
}
#endif
