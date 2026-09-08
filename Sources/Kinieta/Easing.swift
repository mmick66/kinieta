// Kinieta — MIT License. See LICENSE.
// Preset control points are from https://github.com/ai/easings.net/

import Foundation

/// An easing curve: a cubic Bézier that maps a time fraction to progress.
public struct Easing: Sendable, Equatable {

    /// The shape of an easing. Each shape comes in `in`, `out` and `inOut`
    /// placements; `custom` uses the Bézier as given.
    public enum Curve: Sendable, Equatable {
        case sine
        case quad
        case cubic
        case quart
        case quint
        case expo
        case back
        case custom(Bezier)
    }

    let bezier: Bezier

    /// No easing at all.
    public static let linear = Easing(bezier: .linear)

    /// Starts slowly and accelerates.
    public static func `in`(_ curve: Curve = .quad) -> Easing {
        Easing(bezier: resolve(curve, .in))
    }

    /// Starts fast and decelerates.
    public static func out(_ curve: Curve = .quad) -> Easing {
        Easing(bezier: resolve(curve, .out))
    }

    /// Eases at both ends.
    public static func inOut(_ curve: Curve = .quad) -> Easing {
        Easing(bezier: resolve(curve, .inOut))
    }

    /// Any cubic Bézier, for example one taken from cubic-bezier.com.
    public static func custom(_ bezier: Bezier) -> Easing {
        Easing(bezier: bezier)
    }

    enum Placement { case `in`, out, inOut }

    static func resolve(_ curve: Curve, _ placement: Placement) -> Bezier {
        switch (curve, placement) {
        case (.custom(let bezier), _): return bezier

        case (.sine, .in): return Bezier(0.47, 0, 0.745, 0.715)
        case (.sine, .out): return Bezier(0.39, 0.575, 0.565, 1.0)
        case (.sine, .inOut): return Bezier(0.455, 0.03, 0.515, 0.955)

        case (.quad, .in): return Bezier(0.55, 0.085, 0.68, 0.53)
        case (.quad, .out): return Bezier(0.25, 0.46, 0.45, 0.94)
        case (.quad, .inOut): return Bezier(0.455, 0.03, 0.515, 0.955)

        case (.cubic, .in): return Bezier(0.55, 0.055, 0.675, 0.19)
        case (.cubic, .out): return Bezier(0.215, 0.61, 0.355, 1.0)
        case (.cubic, .inOut): return Bezier(0.645, 0.045, 0.355, 1.0)

        case (.quart, .in): return Bezier(0.895, 0.03, 0.685, 0.22)
        case (.quart, .out): return Bezier(0.165, 0.84, 0.44, 1.0)
        case (.quart, .inOut): return Bezier(0.77, 0, 0.175, 1.0)

        case (.quint, .in): return Bezier(0.755, 0.05, 0.855, 0.06)
        case (.quint, .out): return Bezier(0.23, 1.0, 0.32, 1.0)
        case (.quint, .inOut): return Bezier(0.86, 0, 0.07, 1.0)

        case (.expo, .in): return Bezier(0.95, 0.05, 0.795, 0.035)
        case (.expo, .out): return Bezier(0.19, 1.0, 0.22, 1.0)
        case (.expo, .inOut): return Bezier(1.0, 0, 0, 1.0)

        case (.back, .in): return Bezier(0.6, -0.28, 0.735, 0.045)
        case (.back, .out): return Bezier(0.175, 0.885, 0.32, 1.275)
        case (.back, .inOut): return Bezier(0.68, -0.55, 0.265, 1.55)
        }
    }
}
