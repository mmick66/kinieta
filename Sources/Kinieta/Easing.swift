// Kinieta — MIT License. See LICENSE.
// Preset control points are from Matthew Lein's Ceaser table
// (https://matthewlein.com/tools/ceaser). The current easings.net
// (https://github.com/ai/easings.net/) lists different values for some of them.

#if canImport(UIKit) || os(macOS)
import Foundation

/// An easing curve: a cubic Bézier that maps a time fraction to progress.
public struct Easing: Sendable, Equatable {

    /// The shape of an easing. Each shape comes in `in`, `out` and `inOut`
    /// placements. For your own curve use ``Easing/custom(_:)``.
    public enum Curve: Sendable, Equatable {
        /// A sine curve: the gentlest of the presets.
        case sine
        /// A quadratic curve. The default for every placement.
        case quad
        /// A cubic curve, steeper than `quad`.
        case cubic
        /// A quartic curve, steeper than `cubic`.
        case quart
        /// A quintic curve, steeper than `quart`.
        case quint
        /// An exponential curve: the steepest of the presets.
        case expo
        /// A curve that overshoots: it pulls back before it starts, goes past
        /// the target before it settles, or both, depending on the placement.
        case back
        /// Uses the Bézier as given, whatever the placement: `.in(.custom(b))`,
        /// `.out(.custom(b))` and `.inOut(.custom(b))` are all the same curve.
        @available(*, deprecated, message: "use Easing.custom(_:); the in, out or inOut placement is ignored")
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

    /// Any cubic Bézier, for example one taken from cubic-bezier.com, used as given.
    public static func custom(_ bezier: Bezier) -> Easing {
        Easing(bezier: bezier)
    }

    enum Placement { case `in`, out, inOut }

    static func resolve(_ curve: Curve, _ placement: Placement) -> Bezier {
        switch (curve, placement) {
        case (.custom(let bezier), _): return bezier

        case (.sine, .in): return Preset.sineIn
        case (.sine, .out): return Preset.sineOut
        case (.sine, .inOut): return Preset.sineInOut

        case (.quad, .in): return Preset.quadIn
        case (.quad, .out): return Preset.quadOut
        case (.quad, .inOut): return Preset.quadInOut

        case (.cubic, .in): return Preset.cubicIn
        case (.cubic, .out): return Preset.cubicOut
        case (.cubic, .inOut): return Preset.cubicInOut

        case (.quart, .in): return Preset.quartIn
        case (.quart, .out): return Preset.quartOut
        case (.quart, .inOut): return Preset.quartInOut

        case (.quint, .in): return Preset.quintIn
        case (.quint, .out): return Preset.quintOut
        case (.quint, .inOut): return Preset.quintInOut

        case (.expo, .in): return Preset.expoIn
        case (.expo, .out): return Preset.expoOut
        case (.expo, .inOut): return Preset.expoInOut

        case (.back, .in): return Preset.backIn
        case (.back, .out): return Preset.backOut
        case (.back, .inOut): return Preset.backInOut
        }
    }

    /// The preset curves, baked once on first use and shared by every
    /// easing that names them.
    private enum Preset {
        static let sineIn = Bezier(0.47, 0, 0.745, 0.715)
        static let sineOut = Bezier(0.39, 0.575, 0.565, 1.0)
        static let sineInOut = Bezier(0.445, 0.05, 0.55, 0.95)

        static let quadIn = Bezier(0.55, 0.085, 0.68, 0.53)
        static let quadOut = Bezier(0.25, 0.46, 0.45, 0.94)
        static let quadInOut = Bezier(0.455, 0.03, 0.515, 0.955)

        static let cubicIn = Bezier(0.55, 0.055, 0.675, 0.19)
        static let cubicOut = Bezier(0.215, 0.61, 0.355, 1.0)
        static let cubicInOut = Bezier(0.645, 0.045, 0.355, 1.0)

        static let quartIn = Bezier(0.895, 0.03, 0.685, 0.22)
        static let quartOut = Bezier(0.165, 0.84, 0.44, 1.0)
        static let quartInOut = Bezier(0.77, 0, 0.175, 1.0)

        static let quintIn = Bezier(0.755, 0.05, 0.855, 0.06)
        static let quintOut = Bezier(0.23, 1.0, 0.32, 1.0)
        static let quintInOut = Bezier(0.86, 0, 0.07, 1.0)

        static let expoIn = Bezier(0.95, 0.05, 0.795, 0.035)
        static let expoOut = Bezier(0.19, 1.0, 0.22, 1.0)
        static let expoInOut = Bezier(1.0, 0, 0, 1.0)

        static let backIn = Bezier(0.6, -0.28, 0.735, 0.045)
        static let backOut = Bezier(0.175, 0.885, 0.32, 1.275)
        static let backInOut = Bezier(0.68, -0.55, 0.265, 1.55)
    }
}
#endif
