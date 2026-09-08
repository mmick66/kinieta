// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit)
import UIKit

/// How two colours are interpolated.
public enum ColorInterpolation: Sendable, Equatable {
    /// A straight line through sRGB. Cheap, but saturated pairs pass through grey.
    case rgb
    /// Through hue, saturation and brightness, hue along the shorter arc.
    case hsb
    /// Through the perceptual CIE LCH space, hue along the shorter arc. The default.
    case lch
}

/// A view property and the value it should animate to.
public enum Property: Sendable {
    case x(CGFloat)
    case y(CGFloat)
    case width(CGFloat)
    case height(CGFloat)
    case frame(CGRect)
    case alpha(CGFloat)
    /// Rotation about the view's centre, in degrees. Replaces any scale in the transform.
    case rotation(degrees: CGFloat)
    /// `interpolation` overrides `Engine.shared.colorInterpolation` for this property.
    case background(UIColor, interpolation: ColorInterpolation? = nil)
    case borderColor(UIColor, interpolation: ColorInterpolation? = nil)
    case borderWidth(CGFloat)
    case cornerRadius(CGFloat)

    /// Identifies the property regardless of value. When the same property is
    /// listed twice in one animation the last value wins.
    var name: String {
        switch self {
        case .x: return "x"
        case .y: return "y"
        case .width: return "width"
        case .height: return "height"
        case .frame: return "frame"
        case .alpha: return "alpha"
        case .rotation: return "rotation"
        case .background: return "background"
        case .borderColor: return "borderColor"
        case .borderWidth: return "borderWidth"
        case .cornerRadius: return "cornerRadius"
        }
    }

    /// Applies an eased progress factor to a view.
    typealias Transformation = (UIView, CGFloat) -> Void

    /// Builds the per-frame transformation, capturing the view's current value
    /// as the starting point. Call it when the animation starts, not when the
    /// timeline is built.
    @MainActor
    func transformation(for view: UIView, defaultColorInterpolation: ColorInterpolation) -> Transformation {
        switch self {
        case .x(let to):
            return lerp(from: view.x, to: to) { $0.x = $1 }
        case .y(let to):
            return lerp(from: view.y, to: to) { $0.y = $1 }
        case .width(let to):
            return lerp(from: view.width, to: to) { $0.width = max($1, 0) }
        case .height(let to):
            return lerp(from: view.height, to: to) { $0.height = max($1, 0) }
        case .frame(let to):
            return lerp(from: view.frame, to: to) { $0.frame = $1 }
        case .alpha(let to):
            return lerp(from: view.alpha, to: to) { $0.alpha = $1 }
        case .rotation(let to):
            return lerp(from: view.rotation, to: to) { $0.rotation = $1 }
        case .borderWidth(let to):
            return lerp(from: view.layer.borderWidth, to: to) { $0.layer.borderWidth = max($1, 0) }
        case .cornerRadius(let to):
            return lerp(from: view.layer.cornerRadius, to: to) { $0.layer.cornerRadius = max($1, 0) }
        case .background(let to, let mode):
            return colorLerp(from: view.backgroundColorOrClear, to: to, mode: mode ?? defaultColorInterpolation) {
                $0.backgroundColor = $1
            }
        case .borderColor(let to, let mode):
            return colorLerp(from: view.borderColorOrClear, to: to, mode: mode ?? defaultColorInterpolation) {
                $0.layer.borderColor = $1.cgColor
            }
        }
    }

    private func lerp<T: CGFractionable>(from: T, to: T, apply: @escaping (UIView, T) -> Void) -> Transformation {
        return { view, factor in
            apply(view, (1.0 - factor) * from + factor * to)
        }
    }

    /// Colour progress is clamped to 0...1: an overshooting easing has no
    /// meaning outside the gamut. The endpoints are assigned as given, so a
    /// dynamic (light/dark) or wide-gamut target survives the animation.
    private func colorLerp(
        from source: UIColor, to target: UIColor, mode: ColorInterpolation,
        apply: @escaping (UIView, UIColor) -> Void
    ) -> Transformation {
        // A fully transparent endpoint has no colour of its own. Fade the other
        // colour's alpha instead of passing through black.
        var from = source, to = target
        if from.components(as: .RGB).alpha == 0 { from = to.withAlphaComponent(0) }
        if to.components(as: .RGB).alpha == 0 { to = from.withAlphaComponent(0) }

        let between: (CGFloat) -> UIColor
        switch mode {
        case .rgb:
            let f = from.components(as: .RGB), t = to.components(as: .RGB)
            between = { c in UIColor(components: (1.0 - c) * f + c * t) }
        case .hsb:
            var f = from.components(as: .HSB)
            var t = to.components(as: .HSB)
            // A grey endpoint has no hue; borrow the other one's so the
            // interpolation does not sweep through the colour wheel.
            let achromatic: CGFloat = 1e-3
            if f.c2 < achromatic { f.c1 = t.c1 }
            if t.c2 < achromatic { t.c1 = f.c1 }
            // Hue is circular in 0...1: take the shorter way round.
            if t.c1 - f.c1 > 0.5 { t.c1 -= 1 } else if f.c1 - t.c1 > 0.5 { t.c1 += 1 }
            between = { c in
                var comps = (1.0 - c) * f + c * t
                comps.c1 = comps.c1 - floor(comps.c1)
                return UIColor(components: comps)
            }
        case .lch:
            var f = from.rgbColor().toLCH()
            var t = to.rgbColor().toLCH()
            let achromatic: CGFloat = 1e-3
            if f.c < achromatic { f = LCHColor(l: f.l, c: f.c, h: t.h, alpha: f.alpha) }
            if t.c < achromatic { t = LCHColor(l: t.l, c: t.c, h: f.h, alpha: t.alpha) }
            between = { c in f.lerp(t, t: c).toRGB().clamped().color() }
        }

        return { view, factor in
            let c = min(max(factor, 0), 1)
            if c >= 1 { apply(view, target) } else if c <= 0 { apply(view, source) } else { apply(view, between(c)) }
        }
    }
}
#endif
