// Kinieta — MIT License. See LICENSE.

import UIKit

/// Interpolates a set of properties on one view over a duration.
@MainActor
final class Animation: Action {

    private let ref: ViewRef
    private var transformations: [Property.Transformation] = []

    private(set) var easing: Bezier
    private(set) var duration: TimeInterval
    private var elapsed: TimeInterval = 0

    let complete: Block?

    init(_ ref: ViewRef, properties: [Property], duration: TimeInterval, easing: Bezier?, complete: Block?) {
        self.ref      = ref
        self.duration = Engine.shared.shouldSkipMotion ? 0 : duration
        self.easing   = easing ?? .linear
        self.complete = complete

        guard let view = ref.view else { return }

        // The last value listed for a property wins; order of first mention is kept.
        var order: [String] = []
        var latest: [String: Property] = [:]
        for property in properties {
            if latest[property.name] == nil { order.append(property.name) }
            latest[property.name] = property
        }
        let mode = Engine.shared.colorInterpolation
        transformations = order.map { latest[$0]!.transformation(for: view, defaultColorInterpolation: mode) }
    }

    func update(_ frame: Engine.Frame) -> ActionResult {
        // The view was deallocated: there is nothing left to animate.
        guard let view = ref.view else { return .finished }

        guard duration > 0 else {
            apply(1.0, to: view)
            complete?()
            return .finished
        }

        elapsed = min(elapsed + frame.duration, duration)
        let progress = easing.solve(elapsed / duration)
        apply(CGFloat(progress), to: view)

        if elapsed >= duration {
            complete?()
            return .finished
        }
        return .running
    }

    private func apply(_ factor: CGFloat, to view: UIView) {
        for transformation in transformations {
            transformation(view, factor)
        }
    }
}
