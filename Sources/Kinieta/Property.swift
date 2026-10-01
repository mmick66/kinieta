// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit)
import UIKit
#elseif os(macOS)
import AppKit
#endif

#if canImport(UIKit) || os(macOS)
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
/// Beyond the built-in cases, ``custom(_:to:isMotion:)-(ReferenceWritableKeyPath<Root,Value>,_,_)``
/// animates any writable key path to an ``Interpolatable`` value, and
/// ``constant(of:to:)`` animates an Auto Layout constraint's constant.
public enum Property: Sendable {
    case x(CGFloat)
    case y(CGFloat)
    case width(CGFloat)
    case height(CGFloat)
    case frame(CGRect)
    case alpha(CGFloat)
    /// Rotation about the view's centre, in degrees. Starts from the angle the
    /// view was last rotated to, unwrapped. On UIKit it keeps any scale in the
    /// transform. On AppKit it sets `frameRotation` with the centre kept in
    /// place, so positive angles turn counterclockwise unless the superview is
    /// flipped.
    case rotation(degrees: CGFloat)
    #if canImport(UIKit)
    /// `interpolation` overrides `Engine.shared.colorInterpolation` for this property.
    case background(UIColor, interpolation: ColorInterpolation? = nil)
    case borderColor(UIColor, interpolation: ColorInterpolation? = nil)
    #else
    /// The layer's `backgroundColor`; a view without a layer is given one.
    /// `interpolation` overrides `Engine.shared.colorInterpolation` for this property.
    case background(NSColor, interpolation: ColorInterpolation? = nil)
    /// The layer's `borderColor`; a view without a layer is given one.
    case borderColor(NSColor, interpolation: ColorInterpolation? = nil)
    #endif
    /// The layer's `borderWidth`. On AppKit a view without a layer is given one.
    case borderWidth(CGFloat)
    /// The layer's `cornerRadius`. On AppKit a view without a layer is given one.
    case cornerRadius(CGFloat)
    /// A key path or constraint constant. Make one with
    /// ``custom(_:to:isMotion:)-(ReferenceWritableKeyPath<Root,Value>,_,_)`` or ``constant(of:to:)``.
    case extended(CustomProperty)

    /// Identifies a property regardless of value. When the same property is
    /// listed twice in one animation the last value wins.
    enum Key: Hashable {
        case x, y, width, height, frame, alpha, background, borderColor, borderWidth, cornerRadius
        /// The view's `transform`, written by `.rotation` and by a key path to
        /// it, such as `\.transform`, so each takes the other over.
        case transform
        /// A key path, or a constraint by identity.
        case custom(AnyHashable)
    }

    var key: Key {
        switch self {
        case .x: return .x
        case .y: return .y
        case .alpha: return .alpha
        case .width: return .width
        case .height: return .height
        case .frame: return .frame
        case .rotation: return .transform
        case .background: return .background
        case .borderColor: return .borderColor
        case .borderWidth: return .borderWidth
        case .cornerRadius: return .cornerRadius
        case .extended(let custom): return custom.key
        }
    }

    /// The keys the property writes, each of which a newer animation can take
    /// over on its own. `.frame` writes position and size as `.x`, `.y`,
    /// `.width` and `.height`, so a later `.x` takes only the position.
    var keys: [Key] {
        if case .frame = self { return [.x, .y, .width, .height] }
        return [key]
    }

    /// The object whose `keys` the property writes: the view, or the
    /// constraint of a `.constant`, which any view's timeline can animate.
    @MainActor
    func owner(on view: PlatformView) -> ObjectIdentifier {
        if case .extended(let custom) = self, let target = custom.target { return target }
        return ObjectIdentifier(view)
    }

    /// The name used in descriptions and log messages.
    var name: String {
        switch self {
        case .extended(let custom): return custom.name
        case .rotation: return "rotation"
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

    /// Applies an eased progress factor to a view.
    typealias Transformation = (PlatformView, CGFloat) -> Void

    /// Builds the per-frame transformation, capturing the view's current value
    /// as the starting point. Call it when the animation starts, not when the
    /// timeline is built.
    @MainActor
    func transformation(for view: PlatformView, defaultColorInterpolation: ColorInterpolation) -> Transformation {
        switch self {
        case .x(let to):
            return lerp(from: view.x, to: to) { $0.x = $1 }
        case .y(let to):
            return lerp(from: view.y, to: to) { $0.y = $1 }
        case .alpha(let to):
            return lerp(from: view.alpha, to: to) { $0.alpha = $1 }
        case .width(let to):
            return lerp(from: view.width, to: to) { $0.width = max($1, 0) }
        case .height(let to):
            return lerp(from: view.height, to: to) { $0.height = max($1, 0) }
        case .frame:
            let parts = transformations(for: view, defaultColorInterpolation: defaultColorInterpolation)
            return { view, factor in
                for part in parts { part(view, factor) }
            }
        case .rotation(let to):
            return lerp(from: view.rotation, to: to) { $0.rotation = $1 }
        case .background(let to, let mode):
            let colors = Self.colorInterpolator(
                from: view.animatedBackgroundColor, to: to, mode: mode ?? defaultColorInterpolation, view: view,
                name: name)
            return { view, factor in view.animatedBackgroundColor = colors(factor) }
        case .borderColor(let to, let mode):
            let colors = Self.colorInterpolator(
                from: view.animatedBorderColor, to: to, mode: mode ?? defaultColorInterpolation, view: view,
                name: name)
            return { view, factor in view.animatedBorderColor = colors(factor) }
        case .borderWidth(let to):
            return lerp(from: view.animatedBorderWidth, to: to) { $0.animatedBorderWidth = max($1, 0) }
        case .cornerRadius(let to):
            return lerp(from: view.animatedCornerRadius, to: to) { $0.animatedCornerRadius = max($1, 0) }
        case .extended(let custom):
            return custom.transformation(view, defaultColorInterpolation) ?? { _, _ in }
        }
    }

    /// One transformation per key in `keys`, in the same order.
    @MainActor
    func transformations(for view: PlatformView, defaultColorInterpolation: ColorInterpolation) -> [Transformation] {
        guard case .frame(let target) = self else {
            return [transformation(for: view, defaultColorInterpolation: defaultColorInterpolation)]
        }
        // Each side on its own, from the frame before the transform. The size is
        // clamped, not standardised, when an easing overshoots below zero.
        let to = target.standardized
        return [
            lerp(from: view.x, to: to.origin.x) { $0.x = $1 },
            lerp(from: view.y, to: to.origin.y) { $0.y = $1 },
            lerp(from: view.width, to: to.size.width) { $0.width = max($1, 0) },
            lerp(from: view.height, to: to.size.height) { $0.height = max($1, 0) },
        ]
    }

    private func lerp<T: Interpolatable>(from: T, to: T, apply: @escaping (PlatformView, T) -> Void) -> Transformation {
        return { view, factor in
            apply(view, from.interpolated(to: to, progress: factor))
        }
    }

    private static let logger = Logger(subsystem: "Kinieta", category: "Colour")

    /// See ``ColorMath/interpolator(from:to:mode:appearance:)``. A colour with
    /// nothing to blend, such as a pattern, switches as soon as the animation starts.
    ///
    /// Dynamic colours resolve against `view`'s traits, or its effective
    /// appearance on AppKit, and again whenever that changes the colours,
    /// such as dark mode toggled or a sheet raised mid-animation: the colours
    /// in between follow the new variants instead of snapping to them at the end.
    @MainActor
    static func colorInterpolator(
        from source: PlatformColor, to target: PlatformColor, mode: ColorInterpolation, view: PlatformView,
        name: String
    ) -> (CGFloat) -> PlatformColor {
        func colors(for appearance: PlatformAppearance) -> ((CGFloat) -> PlatformColor)? {
            ColorMath.interpolator(from: source, to: target, mode: mode, appearance: appearance)
        }
        var appearance = view.currentAppearance
        guard var current = colors(for: appearance) else {
            logger.warning("\(name, privacy: .public) cannot blend a colour with no RGB value; snapping")
            return { factor in factor > 0 ? target : source }
        }
        return { [weak view] factor in
            if let now = view?.currentAppearance, now.resolvesColorsDifferently(from: appearance) {
                appearance = now
                current = colors(for: now) ?? current
            }
            return current(factor)
        }
    }
}
#endif
