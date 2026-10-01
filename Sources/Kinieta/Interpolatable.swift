// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit)
import UIKit
#elseif os(macOS)
import AppKit
#endif

#if canImport(UIKit) || os(macOS)

/// A value Kinieta can animate: one that can produce the values between itself
/// and another.
///
/// Conform your own types to animate them through
/// ``Property/custom(_:to:isMotion:)-(ReferenceWritableKeyPath<Root,Value>,_,_)``:
///
/// ```swift
/// extension CGVector: Interpolatable {
///     public func interpolated(to target: CGVector, progress: CGFloat) -> CGVector {
///         CGVector(
///             dx: dx.interpolated(to: target.dx, progress: progress),
///             dy: dy.interpolated(to: target.dy, progress: progress))
///     }
/// }
/// ```
///
/// Kinieta provides conformances for `CGFloat`, `Double`, `Float`, `CGPoint`,
/// `CGSize`, `CGRect`, `CGAffineTransform`, `UIColor` (`NSColor` on AppKit)
/// and `CGColor`.
public protocol Interpolatable {
    /// The value `progress` of the way from `self` to `target`.
    ///
    /// Progress 0 is `self` and 1 is `target`. An easing curve that overshoots,
    /// such as `back`, passes progress below 0 or above 1; extrapolate when
    /// that has a meaning for the type, clamp when it does not.
    func interpolated(to target: Self, progress: CGFloat) -> Self
}

extension CGFloat: Interpolatable {
    /// The value `progress` of the way to `target`, along a straight line.
    /// Exactly `target` at progress 1, which `self + (target - self) * progress` is not.
    public func interpolated(to target: CGFloat, progress: CGFloat) -> CGFloat {
        (1 - progress) * self + progress * target
    }
}

extension Double: Interpolatable {
    /// The value `progress` of the way to `target`, along a straight line, like `CGFloat`.
    public func interpolated(to target: Double, progress: CGFloat) -> Double {
        let t = Double(progress)
        return (1 - t) * self + t * target
    }
}

extension Float: Interpolatable {
    /// The value `progress` of the way to `target`, along a straight line, like `CGFloat`.
    public func interpolated(to target: Float, progress: CGFloat) -> Float {
        let t = Float(progress)
        return (1 - t) * self + t * target
    }
}

extension CGPoint: Interpolatable {
    /// The point `progress` of the way to `target`, along a straight line.
    public func interpolated(to target: CGPoint, progress: CGFloat) -> CGPoint {
        CGPoint(
            x: x.interpolated(to: target.x, progress: progress),
            y: y.interpolated(to: target.y, progress: progress))
    }
}

extension CGSize: Interpolatable {
    /// The size `progress` of the way to `target`, width and height each linearly.
    public func interpolated(to target: CGSize, progress: CGFloat) -> CGSize {
        CGSize(
            width: width.interpolated(to: target.width, progress: progress),
            height: height.interpolated(to: target.height, progress: progress))
    }
}

extension CGRect: Interpolatable {
    /// The rectangle `progress` of the way to `target`.
    /// Origin and size separately, as given: neither end is standardised.
    public func interpolated(to target: CGRect, progress: CGFloat) -> CGRect {
        CGRect(
            origin: origin.interpolated(to: target.origin, progress: progress),
            size: size.interpolated(to: target.size, progress: progress))
    }
}

extension CGAffineTransform: Interpolatable {
    /// The transform `progress` of the way to `target`, decomposed like Core
    /// Animation does rather than blended entry by entry, which would shrink
    /// a view as it rotates.
    ///
    /// Each end is split into a translation, a rotation, a scale on each axis
    /// and a shear, applied in the order scale, shear, rotation, translation;
    /// the parts are interpolated and composed again. The rotation takes the
    /// shorter way round, since a transform cannot tell a half turn from one
    /// and a half: for more, animate ``Property/rotation(degrees:)``. A flip,
    /// such as `CGAffineTransform(scaleX: -1, y: 1)`, scales through zero
    /// instead of turning. A transform that scales to nothing takes its
    /// rotation from the other end. Progress 0 and 1 give the ends exactly.
    public func interpolated(to target: CGAffineTransform, progress: CGFloat) -> CGAffineTransform {
        if progress == 0 { return self }
        if progress == 1 { return target }
        var from = AffineParts(self), to = AffineParts(target)
        // A flip on either axis combined with a half turn is the same flip on
        // the other axis. Match them so a flip does not turn on the way.
        if (from.scaleX < 0 && to.scaleY < 0) || (from.scaleY < 0 && to.scaleX < 0) { from.turnHalfWay() }
        let fromAngle = from.angle ?? to.angle ?? 0
        let toAngle = to.angle ?? fromAngle
        return AffineParts(
            translation: from.translation.interpolated(to: to.translation, progress: progress),
            scaleX: from.scaleX.interpolated(to: to.scaleX, progress: progress),
            scaleY: from.scaleY.interpolated(to: to.scaleY, progress: progress),
            shear: from.shear.interpolated(to: to.shear, progress: progress),
            angle: fromAngle + (toAngle - fromAngle).remainder(dividingBy: 2 * .pi) * progress
        ).transform
    }
}

/// A transform as a scale, a shear, a rotation and a translation, applied in
/// that order: the linear part is `[[scaleX, 0], [shear, scaleY]]` times the
/// rotation, in Core Graphics' row-vector convention.
private struct AffineParts {
    var translation: CGPoint
    var scaleX: CGFloat
    var scaleY: CGFloat
    var shear: CGFloat
    /// In radians; `nil` when the linear part is zero and has no direction.
    var angle: CGFloat?

    init(translation: CGPoint, scaleX: CGFloat, scaleY: CGFloat, shear: CGFloat, angle: CGFloat?) {
        self.translation = translation
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.shear = shear
        self.angle = angle
    }

    init(_ t: CGAffineTransform) {
        translation = CGPoint(x: t.tx, y: t.ty)
        scaleX = hypot(t.a, t.b)
        // A mirror image puts its flip on the axis that is flipped most, as
        // CSS does, so a flip in x stays a flip in x.
        if t.a * t.d - t.b * t.c < 0, t.a < t.d { scaleX = -scaleX }
        if scaleX != 0 {
            let cosine = t.a / scaleX, sine = t.b / scaleX
            angle = atan2(sine, cosine)
            shear = t.c * cosine + t.d * sine
            scaleY = t.d * cosine - t.c * sine
        } else {
            // The x axis collapses: the rotation is wherever the y axis points.
            let length = hypot(t.c, t.d)
            angle = length == 0 ? nil : atan2(-t.c, t.d)
            shear = 0
            scaleY = length
        }
    }

    /// The same transform with both axes flipped and half a turn added.
    mutating func turnHalfWay() {
        scaleX = -scaleX
        scaleY = -scaleY
        shear = -shear
        angle = angle.map { $0 + .pi }
    }

    var transform: CGAffineTransform {
        let cosine = cos(angle ?? 0), sine = sin(angle ?? 0)
        return CGAffineTransform(
            a: scaleX * cosine, b: scaleX * sine,
            c: shear * cosine - scaleY * sine, d: shear * sine + scaleY * cosine,
            tx: translation.x, ty: translation.y)
    }
}

#if canImport(UIKit)
extension UIColor: Interpolatable {}

extension Interpolatable where Self: UIColor {
    /// The colour `progress` of the way to `target` through LCH, as
    /// ``ColorInterpolation/lch`` describes, with progress clamped to 0...1.
    ///
    /// Dynamic colours resolve against the current traits. A colour animated
    /// through ``Property/custom(_:to:isMotion:)-(ReferenceWritableKeyPath<UIView,Value>,_,_)``
    /// takes `Engine.shared.colorInterpolation` instead and resolves against
    /// the view's own traits, exactly like ``Property/background(_:interpolation:)``.
    public func interpolated(to target: Self, progress: CGFloat) -> Self {
        interpolatedColor(from: self, to: target, progress: progress)
    }
}
#else
extension NSColor: Interpolatable {}

extension Interpolatable where Self: NSColor {
    /// The colour `progress` of the way to `target` through LCH, as
    /// ``ColorInterpolation/lch`` describes, with progress clamped to 0...1.
    ///
    /// Dynamic colours resolve against the current drawing appearance. A
    /// colour animated through
    /// ``Property/custom(_:to:isMotion:)-(ReferenceWritableKeyPath<NSView,Value>,_,_)``
    /// takes `Engine.shared.colorInterpolation` instead and resolves against
    /// the view's effective appearance, exactly like
    /// ``Property/background(_:interpolation:)``.
    public func interpolated(to target: Self, progress: CGFloat) -> Self {
        interpolatedColor(from: self, to: target, progress: progress)
    }
}
#endif

/// The `UIColor` or `NSColor` conformance, which cannot be written once:
/// a public extension cannot be constrained through the internal `PlatformColor`.
private func interpolatedColor<Color: PlatformColor>(from source: Color, to target: Color, progress: CGFloat) -> Color {
    let color = ColorMath.interpolator(from: source, to: target, mode: .lch, appearance: nil)?(progress)
    // A pattern has nothing to blend, so it switches; a subclass cannot be made, so it switches too.
    return color as? Color ?? (progress > 0 ? target : source)
}

extension CGColor: Interpolatable {}

extension Interpolatable where Self: CGColor {
    /// The colour `progress` of the way to `target` through LCH, like
    /// `UIColor`, or `NSColor` on AppKit, with progress clamped to 0...1. The
    /// colours in between are sRGB, or Display P3 when an end is outside sRGB.
    ///
    /// A colour animated through
    /// ``Property/custom(_:to:isMotion:)-(ReferenceWritableKeyPath<Root,Value>,_,_)``,
    /// such as `\.layer.shadowColor`, takes `Engine.shared.colorInterpolation` instead.
    public func interpolated(to target: Self, progress: CGFloat) -> Self {
        if progress <= 0 { return self }
        if progress >= 1 { return target }
        #if canImport(UIKit)
        let (from, to) = (UIColor(cgColor: self), UIColor(cgColor: target))
        #else
        guard let from = NSColor(cgColor: self), let to = NSColor(cgColor: target) else { return target }
        #endif
        let colors = ColorMath.interpolator(from: from, to: to, mode: .lch, appearance: nil)
        // A pattern has nothing to blend, so it switches.
        return colors?(progress).cgColor as? Self ?? target
    }
}
#endif
