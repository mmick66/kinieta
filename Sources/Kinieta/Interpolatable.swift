// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit)
import UIKit

/// A value Kinieta can animate: one that can produce the values between itself
/// and another.
///
/// Conform your own types to animate them through
/// ``Property/custom(_:to:isMotion:)-(ReferenceWritableKeyPath<UIView,Value>,_,_)``:
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
/// `CGSize`, `CGRect` and `UIColor`.
public protocol Interpolatable {
    /// The value `progress` of the way from `self` to `target`.
    ///
    /// Progress 0 is `self` and 1 is `target`. An easing curve that overshoots,
    /// such as `back`, passes progress below 0 or above 1; extrapolate when
    /// that has a meaning for the type, clamp when it does not.
    func interpolated(to target: Self, progress: CGFloat) -> Self
}

extension CGFloat: Interpolatable {
    /// Exactly `target` at progress 1, which `self + (target - self) * progress` is not.
    public func interpolated(to target: CGFloat, progress: CGFloat) -> CGFloat {
        (1 - progress) * self + progress * target
    }
}

extension Double: Interpolatable {
    public func interpolated(to target: Double, progress: CGFloat) -> Double {
        let t = Double(progress)
        return (1 - t) * self + t * target
    }
}

extension Float: Interpolatable {
    public func interpolated(to target: Float, progress: CGFloat) -> Float {
        let t = Float(progress)
        return (1 - t) * self + t * target
    }
}

extension CGPoint: Interpolatable {
    public func interpolated(to target: CGPoint, progress: CGFloat) -> CGPoint {
        CGPoint(
            x: x.interpolated(to: target.x, progress: progress),
            y: y.interpolated(to: target.y, progress: progress))
    }
}

extension CGSize: Interpolatable {
    public func interpolated(to target: CGSize, progress: CGFloat) -> CGSize {
        CGSize(
            width: width.interpolated(to: target.width, progress: progress),
            height: height.interpolated(to: target.height, progress: progress))
    }
}

extension CGRect: Interpolatable {
    /// Origin and size separately, as given: neither end is standardised.
    public func interpolated(to target: CGRect, progress: CGFloat) -> CGRect {
        CGRect(
            origin: origin.interpolated(to: target.origin, progress: progress),
            size: size.interpolated(to: target.size, progress: progress))
    }
}

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
        let color = ColorMath.interpolator(from: self, to: target, mode: .lch, traits: nil)?(progress)
        // A pattern has nothing to blend, so it switches; a subclass cannot be made, so it switches too.
        return color as? Self ?? (progress > 0 ? target : self)
    }
}
#endif
