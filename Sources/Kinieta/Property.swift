// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit)
import UIKit
import os

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
    /// Rotation about the view's centre, in degrees. Starts from the angle the
    /// view was last rotated to, unwrapped, and keeps any scale in the transform.
    case rotation(degrees: CGFloat)
    /// `interpolation` overrides `Engine.shared.colorInterpolation` for this property.
    case background(UIColor, interpolation: ColorInterpolation? = nil)
    case borderColor(UIColor, interpolation: ColorInterpolation? = nil)
    case borderWidth(CGFloat)
    case cornerRadius(CGFloat)

    /// Identifies a property regardless of value. When the same property is
    /// listed twice in one animation the last value wins.
    enum Key: String {
        case x, y, width, height, frame, alpha, rotation, background, borderColor, borderWidth, cornerRadius

        /// Whether the property moves, resizes or rotates the view. Under
        /// Reduce Motion these snap; fades and colour changes still animate.
        var isMotion: Bool {
            switch self {
            case .x, .y, .width, .height, .frame, .rotation: return true
            case .alpha, .background, .borderColor, .borderWidth, .cornerRadius: return false
            }
        }
    }

    var key: Key {
        switch self {
        case .x: return .x
        case .y: return .y
        case .width: return .width
        case .height: return .height
        case .frame: return .frame
        case .alpha: return .alpha
        case .rotation: return .rotation
        case .background: return .background
        case .borderColor: return .borderColor
        case .borderWidth: return .borderWidth
        case .cornerRadius: return .cornerRadius
        }
    }

    private static let logger = Logger(subsystem: "Kinieta", category: "Colour")

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
            // `size`, not `width`/`height`: those standardise a negative overshoot.
            return lerp(from: view.untransformedFrame, to: to.standardized) { view, rect in
                let size = CGSize(width: max(rect.size.width, 0), height: max(rect.size.height, 0))
                view.untransformedFrame = CGRect(origin: rect.origin, size: size)
            }
        case .alpha(let to):
            return lerp(from: view.alpha, to: to) { $0.alpha = $1 }
        case .rotation(let to):
            return lerp(from: view.rotation, to: to) { $0.rotation = $1 }
        case .borderWidth(let to):
            return lerp(from: view.layer.borderWidth, to: to) { $0.layer.borderWidth = max($1, 0) }
        case .cornerRadius(let to):
            return lerp(from: view.layer.cornerRadius, to: to) { $0.layer.cornerRadius = max($1, 0) }
        case .background(let to, let mode):
            return colorLerp(
                from: view.backgroundColorOrClear, to: to, mode: mode ?? defaultColorInterpolation,
                traits: view.currentTraits
            ) { $0.backgroundColor = $1 }
        case .borderColor(let to, let mode):
            return colorLerp(
                from: view.borderColorOrClear, to: to, mode: mode ?? defaultColorInterpolation,
                traits: view.currentTraits
            ) { $0.layer.borderColor = $1.cgColor }
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
    ///
    /// The frames in between are clipped to the smallest of sRGB and Display P3
    /// that holds both endpoints, so a wide-gamut move does not pop at the end.
    /// They are resolved against the view's own `traits`:
    /// inside a display-link callback `UITraitCollection.current` is the
    /// app-wide fallback, which ignores `overrideUserInterfaceStyle` and
    /// presentation-level appearance.
    private func colorLerp(
        from source: UIColor, to target: UIColor, mode: ColorInterpolation, traits: UITraitCollection,
        apply: @escaping (UIView, UIColor) -> Void
    ) -> Transformation {
        guard var from = ColorMath.extractComponents(of: source.resolvedColor(with: traits)),
            var to = ColorMath.extractComponents(of: target.resolvedColor(with: traits))
        else {
            // A pattern has nothing to blend. Switch as soon as the animation starts.
            Self.logger.warning("\(key.rawValue, privacy: .public) cannot blend a colour with no RGB value; snapping")
            return { view, factor in apply(view, factor > 0 ? target : source) }
        }

        // A fully transparent endpoint has no colour of its own. Fade the other
        // colour's alpha instead of passing through black.
        if from.alpha == 0 { from = to.withAlpha(0) }
        if to.alpha == 0 { to = from.withAlpha(0) }

        let path: (CGFloat) -> ColorMath.RGB
        switch mode {
        case .rgb:
            path = { c in from.lerp(to, c) }
        case .hsb:
            // A grey endpoint has no hue; borrow the other one's so the
            // interpolation does not sweep through the colour wheel. Hue then
            // takes the shorter way round.
            let achromatic: CGFloat = 1e-3
            var f = from.hsb, t = to.hsb
            if f.saturation < achromatic { f.hue = t.hue }
            if t.saturation < achromatic { t.hue = f.hue }
            path = { c in f.lerp(t, c).rgb }
        case .lch:
            // LCH.lerp weights hue by chroma, which covers greys and near-greys.
            let f = from.lch, t = to.lch
            path = { c in f.lerp(t, c).rgb }
        }
        // Clip to sRGB only when both ends are in it; Display P3 ends keep
        // their saturation on the way.
        let gamut = ColorMath.Gamut.smallest(containing: from, to)
        let between = { (c: CGFloat) in gamut.clip(path(c)).color() }

        return { view, factor in
            let c = min(max(factor, 0), 1)
            if c >= 1 { apply(view, target) } else if c <= 0 { apply(view, source) } else { apply(view, between(c)) }
        }
    }
}
#endif
