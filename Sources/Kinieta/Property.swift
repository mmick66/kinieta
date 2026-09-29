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
///
/// Beyond the built-in cases, ``custom(_:to:isMotion:)-(ReferenceWritableKeyPath<UIView,Value>,_,_)``
/// animates any writable key path to an ``Interpolatable`` value, and
/// ``constant(_:to:)`` animates an Auto Layout constraint's constant.
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
    /// A key path or constraint constant. Make one with
    /// ``custom(_:to:isMotion:)-(ReferenceWritableKeyPath<UIView,Value>,_,_)`` or ``constant(_:to:)``.
    case extended(CustomProperty)

    /// Identifies a property regardless of value. When the same property is
    /// listed twice in one animation the last value wins.
    enum Key: Hashable {
        case x, y, width, height, frame, alpha, rotation, background, borderColor, borderWidth, cornerRadius
        /// A key path, or a constraint by identity.
        case custom(AnyHashable)
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
        case .extended(let custom): return .custom(custom.key)
        }
    }

    /// The name used in descriptions and log messages.
    var name: String {
        switch self {
        case .extended(let custom): return custom.name
        default: return String(describing: key)
        }
    }

    /// Whether the property moves, resizes or rotates something. Under
    /// Reduce Motion these snap; fades and colour changes still animate.
    var isMotion: Bool {
        switch self {
        case .x, .y, .width, .height, .frame, .rotation: return true
        case .alpha, .background, .borderColor, .borderWidth, .cornerRadius: return false
        case .extended(let custom): return custom.isMotion
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
            let colors = Self.colorInterpolator(
                from: view.backgroundColorOrClear, to: to, mode: mode ?? defaultColorInterpolation,
                traits: view.currentTraits, name: name)
            return { view, factor in view.backgroundColor = colors(factor) }
        case .borderColor(let to, let mode):
            let colors = Self.colorInterpolator(
                from: view.borderColorOrClear, to: to, mode: mode ?? defaultColorInterpolation,
                traits: view.currentTraits, name: name)
            return { view, factor in view.layer.borderColor = colors(factor).cgColor }
        case .extended(let custom):
            return custom.transformation(view, defaultColorInterpolation) ?? { _, _ in }
        }
    }

    private func lerp<T: Interpolatable>(from: T, to: T, apply: @escaping (UIView, T) -> Void) -> Transformation {
        return { view, factor in
            apply(view, from.interpolated(to: to, progress: factor))
        }
    }

    /// See ``ColorMath/interpolator(from:to:mode:traits:)``. A colour with
    /// nothing to blend, such as a pattern, switches as soon as the animation starts.
    static func colorInterpolator(
        from source: UIColor, to target: UIColor, mode: ColorInterpolation, traits: UITraitCollection, name: String
    ) -> (CGFloat) -> UIColor {
        if let colors = ColorMath.interpolator(from: source, to: target, mode: mode, traits: traits) { return colors }
        logger.warning("\(name, privacy: .public) cannot blend a colour with no RGB value; snapping")
        return { factor in factor > 0 ? target : source }
    }
}
#endif
