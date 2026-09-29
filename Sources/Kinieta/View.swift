// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit)
import UIKit
#elseif os(macOS)
import AppKit
#endif

#if canImport(UIKit) || os(macOS)

// `UIView`, or `NSView` on native macOS.
public extension PlatformView {

    /// Starts a timeline that animates `properties` over `duration` seconds.
    /// Chain further calls on the returned handle to extend it.
    @discardableResult
    func animate(_ properties: Property..., duration: TimeInterval = 0) -> Kinieta {
        Kinieta(view: self).animate(properties, duration: duration)
    }

    @discardableResult
    func animate(_ properties: [Property], duration: TimeInterval = 0) -> Kinieta {
        Kinieta(view: self).animate(properties, duration: duration)
    }

    /// Starts a timeline with a pause, for chaining an animation after a delay.
    @discardableResult
    func wait(_ time: TimeInterval) -> Kinieta {
        Kinieta(view: self).wait(time)
    }
}

// MARK: - Geometry helpers used by the interpolators

#if canImport(UIKit)
//
// Position and size go through `center` and `bounds`, not `frame`, so they
// stay meaningful while a rotation is applied. With an identity transform
// they are exactly the frame's origin and size.

extension UIView {

    var x: CGFloat {
        get { center.x - bounds.width * layer.anchorPoint.x }
        set { center.x = newValue + bounds.width * layer.anchorPoint.x }
    }

    var y: CGFloat {
        get { center.y - bounds.height * layer.anchorPoint.y }
        set { center.y = newValue + bounds.height * layer.anchorPoint.y }
    }

    /// Resizing keeps the top-left corner where it is, like setting `frame.size`.
    var width: CGFloat {
        get { bounds.width }
        set {
            let x = self.x
            bounds.size.width = newValue
            self.x = x
        }
    }

    var height: CGFloat {
        get { bounds.height }
        set {
            let y = self.y
            bounds.size.height = newValue
            self.y = y
        }
    }

    /// The frame the view has before its transform is applied: `x`, `y`,
    /// `width` and `height` together. Unlike `frame` it stays defined while a
    /// rotation is applied. Sizes are taken as given, not standardised.
    var untransformedFrame: CGRect {
        get { CGRect(x: x, y: y, width: width, height: height) }
        set {
            bounds.size = newValue.size
            x = newValue.origin.x
            y = newValue.origin.y
        }
    }

    /// Rotation in degrees, unwrapped: after rotating to 720 it reads 720, not 0.
    ///
    /// Setting it keeps the rest of the transform: the scale (and any shear)
    /// applied before the rotation, and the translation.
    ///
    /// The logical angle is remembered together with the transform it produced.
    /// If something else has changed the transform since, the angle is read
    /// back from the transform instead, wrapped to (-180, 180].
    var rotation: CGFloat {
        get {
            if let state = rotationState, state.transform == transform { return state.degrees }
            return atan2(transform.b, transform.a).radiansToDegrees
        }
        set {
            let base: CGAffineTransform
            if let state = rotationState, state.transform == transform {
                // Reuse the stored base so repeated frames do not accumulate rounding.
                base = state.base
            } else {
                // Undo the current rotation to leave whatever was applied before it.
                var linear = transform
                linear.tx = 0
                linear.ty = 0
                base = linear.concatenating(CGAffineTransform(rotationAngle: -atan2(transform.b, transform.a)))
            }
            var rotated = base.concatenating(CGAffineTransform(rotationAngle: newValue.degreesToRadians))
            rotated.tx = transform.tx
            rotated.ty = transform.ty
            transform = rotated
            rotationState = RotationState(degrees: newValue, base: base, transform: rotated)
        }
    }

    private var rotationState: RotationState? {
        get { objc_getAssociatedObject(self, &rotationStateKey) as? RotationState }
        set { objc_setAssociatedObject(self, &rotationStateKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var backgroundColorOrClear: UIColor {
        backgroundColor ?? .clear
    }

    var borderColorOrClear: UIColor {
        layer.borderColor.map { UIColor(cgColor: $0) } ?? .clear
    }

    /// The view's traits with any pending change applied, such as an
    /// `overrideUserInterfaceStyle` set since the last layout pass.
    var currentTraits: UITraitCollection {
        updateTraitsIfNeeded()
        return traitCollection
    }
}

/// The last angle Kinieta gave a view, with the parts of the transform it was
/// composed from.
private final class RotationState {
    let degrees: CGFloat
    /// The linear part of the transform without the rotation, no translation.
    let base: CGAffineTransform
    /// The transform written for `degrees`, to tell whether it is still current.
    let transform: CGAffineTransform

    init(degrees: CGFloat, base: CGAffineTransform, transform: CGAffineTransform) {
        self.degrees = degrees
        self.base = base
        self.transform = transform
    }
}

nonisolated(unsafe) private var rotationStateKey: UInt8 = 0

#else

// AppKit has no `center`, and a view is positioned by its frame in its
// superview's coordinates: from the bottom left unless the superview is
// flipped. `.x` and `.y` write the frame's origin, which is what an AppKit
// developer expects them to mean.

extension NSView {

    var x: CGFloat {
        get { frame.origin.x }
        set { setFrameOrigin(NSPoint(x: newValue, y: frame.origin.y)) }
    }

    var y: CGFloat {
        get { frame.origin.y }
        set { setFrameOrigin(NSPoint(x: frame.origin.x, y: newValue)) }
    }

    /// `alphaValue`, under UIKit's name, so both platforms share `.alpha`.
    var alpha: CGFloat {
        get { alphaValue }
        set { alphaValue = newValue }
    }
}
#endif
#endif
