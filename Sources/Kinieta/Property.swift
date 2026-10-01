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
///
/// Positions and sizes are in points, in the superview's coordinate space, and
/// describe the frame the view has before it is rotated: on UIKit they go
/// through `center` and `bounds`, on AppKit through the unrotated frame about
/// its centre. With no rotation they are exactly the view's `frame`.
public enum Property: Sendable {
    /// The frame's horizontal origin, in points.
    case x(CGFloat)
    /// The frame's vertical origin, in points. On AppKit it is the bottom edge
    /// unless the superview is flipped.
    case y(CGFloat)
    /// The width, in points. The origin stays where it is.
    case width(CGFloat)
    /// The height, in points. The origin stays where it is.
    case height(CGFloat)
    /// The origin and size together, in points: `.x`, `.y`, `.width` and
    /// `.height` in one, each of which a later animation can take over on its own.
    case frame(CGRect)
    /// The opacity, from 0 to 1: `alpha` on UIKit, `alphaValue` on AppKit.
    case alpha(CGFloat)
    /// Rotation about the view's centre, in degrees. Starts from the angle the
    /// view was last rotated to, unwrapped. On UIKit it keeps any scale in the
    /// transform. On AppKit it sets `frameRotation` with the centre kept in
    /// place, so positive angles turn counterclockwise unless the superview is
    /// flipped.
    case rotation(degrees: CGFloat)
    #if canImport(UIKit)
    /// The view's `backgroundColor`, clear when it has none.
    /// `interpolation` overrides `Engine.shared.colorInterpolation` for this property.
    case background(UIColor, interpolation: ColorInterpolation? = nil)
    /// The layer's `borderColor`, clear when it has none.
    /// `interpolation` overrides `Engine.shared.colorInterpolation` for this property.
    case borderColor(UIColor, interpolation: ColorInterpolation? = nil)
    #else
    /// The layer's `backgroundColor`; a view without a layer is given one.
    /// `interpolation` overrides `Engine.shared.colorInterpolation` for this property.
    case background(NSColor, interpolation: ColorInterpolation? = nil)
    /// The layer's `borderColor`; a view without a layer is given one.
    /// `interpolation` overrides `Engine.shared.colorInterpolation` for this property.
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

    /// What the property writes and how it animates, the same for built-in
    /// cases as for ``extended(_:)``. It holds a closure, so an animation
    /// takes it once when it starts rather than once per member it reads.
    var descriptor: CustomProperty {
        switch self {
        case .x(let to):
            return CustomProperty(key: .x, name: "x", isMotion: true) { view, _ in
                Self.lerp(from: view.x, to: to) { $0.x = $1 }
            }
        case .y(let to):
            return CustomProperty(key: .y, name: "y", isMotion: true) { view, _ in
                Self.lerp(from: view.y, to: to) { $0.y = $1 }
            }
        case .width(let to):
            return CustomProperty(key: .width, name: "width", isMotion: true) { view, _ in
                Self.lerp(from: view.width, to: to) { $0.width = max($1, 0) }
            }
        case .height(let to):
            return CustomProperty(key: .height, name: "height", isMotion: true) { view, _ in
                Self.lerp(from: view.height, to: to) { $0.height = max($1, 0) }
            }
        case .frame(let target):
            // Each side on its own, from the frame before the transform. The size is
            // clamped, not standardised, when an easing overshoots below zero.
            let to = target.standardized
            let sides: [Property] = [.x(to.origin.x), .y(to.origin.y), .width(to.size.width), .height(to.size.height)]
            return CustomProperty(key: .frame, name: "frame", isMotion: true, parts: sides.map(\.descriptor))
        case .alpha(let to):
            return CustomProperty(key: .alpha, name: "alpha", isMotion: false) { view, _ in
                Self.lerp(from: view.alpha, to: to) { $0.alpha = $1 }
            }
        case .rotation(let to):
            return CustomProperty(key: .transform, name: "rotation", isMotion: true) { view, _ in
                Self.lerp(from: view.rotation, to: to) { $0.rotation = $1 }
            }
        case .background(let to, let mode):
            return CustomProperty(key: .background, name: "background", isMotion: false) { view, defaultMode in
                let colors = Self.colorInterpolator(
                    from: view.animatedBackgroundColor, to: to, mode: mode ?? defaultMode, view: view,
                    name: "background")
                return { view, factor in view.animatedBackgroundColor = colors(factor) }
            }
        case .borderColor(let to, let mode):
            return CustomProperty(key: .borderColor, name: "borderColor", isMotion: false) { view, defaultMode in
                let colors = Self.colorInterpolator(
                    from: view.animatedBorderColor, to: to, mode: mode ?? defaultMode, view: view,
                    name: "borderColor")
                return { view, factor in view.animatedBorderColor = colors(factor) }
            }
        case .borderWidth(let to):
            return CustomProperty(key: .borderWidth, name: "borderWidth", isMotion: false) { view, _ in
                Self.lerp(from: view.animatedBorderWidth, to: to) { $0.animatedBorderWidth = max($1, 0) }
            }
        case .cornerRadius(let to):
            return CustomProperty(key: .cornerRadius, name: "cornerRadius", isMotion: false) { view, _ in
                Self.lerp(from: view.animatedCornerRadius, to: to) { $0.animatedCornerRadius = max($1, 0) }
            }
        case .extended(let custom):
            return custom
        }
    }

    var key: Key { descriptor.key }

    /// The name used in descriptions and log messages.
    var name: String { descriptor.name }

    /// Whether the property moves, resizes or rotates something. Under
    /// Reduce Motion these snap; fades and colour changes still animate.
    var isMotion: Bool { descriptor.isMotion }

    /// Applies an eased progress factor to a view.
    typealias Transformation = (PlatformView, CGFloat) -> Void

    /// Builds the per-frame transformation, capturing the view's current value
    /// as the starting point. Call it when the animation starts, not when the
    /// timeline is built.
    @MainActor
    func transformation(for view: PlatformView, defaultColorInterpolation: ColorInterpolation) -> Transformation {
        descriptor.transformation(for: view, defaultColorInterpolation: defaultColorInterpolation)
    }

    private static func lerp<T: Interpolatable>(
        from: T, to: T, apply: @escaping (PlatformView, T) -> Void
    ) -> Transformation {
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
