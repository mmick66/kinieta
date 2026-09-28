// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit)
import UIKit

/// Interpolates a set of properties on one view over a duration.
@MainActor
final class PropertyAnimation: Action {

    private let target: ViewRef
    private var transformations: [Property.Transformation] = []

    let easing: Bezier
    let duration: TimeInterval
    private var elapsed: TimeInterval = 0

    let completion: Block?

    init(_ spec: AnimationSpec) {
        self.target = spec.target
        self.duration = Engine.shared.shouldSkipMotion ? 0 : spec.duration
        self.easing = spec.easing ?? .linear
        self.completion = spec.completion

        guard let view = target.view else { return }

        // The last value listed for a property wins; order of first mention is kept.
        var order: [Property.Key] = []
        var latest: [Property.Key: Property] = [:]
        for property in spec.properties {
            if latest[property.key] == nil { order.append(property.key) }
            latest[property.key] = property
        }
        let mode = Engine.shared.colorInterpolation
        transformations = order.map { latest[$0]!.transformation(for: view, defaultColorInterpolation: mode) }
    }

    func update(_ frame: Engine.Frame) -> ActionResult {
        // The view was deallocated: there is nothing left to animate.
        guard let view = target.view else { return .finished(overshoot: frame.duration) }

        guard duration > 0 else {
            apply(1.0, to: view)
            completion?()
            return .finished(overshoot: frame.duration)
        }

        let total = elapsed + frame.duration
        elapsed = min(total, duration)
        let progress = easing.solve(elapsed / duration)
        apply(CGFloat(progress), to: view)

        if elapsed >= duration {
            completion?()
            return .finished(overshoot: total - duration)
        }
        return .running
    }

    private func apply(_ factor: CGFloat, to view: UIView) {
        for transformation in transformations {
            transformation(view, factor)
        }
    }
}
#endif
