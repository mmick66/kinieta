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

// AppKit has no `center` or `transform`: a view is positioned by its frame in
// its superview's coordinates, from the bottom left unless the superview is
// flipped, and turned by `frameRotation` about the frame's origin. So that
// position, size and rotation animate independently, as on UIKit, they work
// on the frame the view would have unrotated, turned about its centre: `.x`
// and `.y` are that frame's origin, which is exactly `frame.origin` while the
// view is not rotated, and a rotation leaves the centre where it is.

extension NSView {

    var x: CGFloat {
        get { untransformedOrigin.x }
        set { untransformedOrigin.x = newValue }
    }

    var y: CGFloat {
        get { untransformedOrigin.y }
        set { untransformedOrigin.y = newValue }
    }

    /// Resizing keeps the unrotated origin where it is, like `setFrameSize`
    /// on a view that is not rotated.
    var width: CGFloat {
        get { frame.width }
        set {
            let origin = untransformedOrigin
            setFrameSize(NSSize(width: newValue, height: frame.height))
            untransformedOrigin = origin
        }
    }

    var height: CGFloat {
        get { frame.height }
        set {
            let origin = untransformedOrigin
            setFrameSize(NSSize(width: frame.width, height: newValue))
            untransformedOrigin = origin
        }
    }

    /// `x`, `y`, `width` and `height` together: `frame` while the view is not
    /// rotated. Sizes are taken as given, not standardised.
    var untransformedFrame: CGRect {
        get { CGRect(origin: untransformedOrigin, size: frame.size) }
        set {
            setFrameSize(newValue.size)
            untransformedOrigin = newValue.origin
        }
    }

    /// The frame's origin before `frameRotation` turns it about the frame's
    /// centre. `frame.origin` is the corner the rotation pivots on, so the
    /// two differ by the centre's offset from it, rotated or not; with no
    /// rotation that difference is exactly zero.
    private var untransformedOrigin: CGPoint {
        get {
            let offset = pivotOffset
            return CGPoint(x: frame.origin.x + offset.dx, y: frame.origin.y + offset.dy)
        }
        set {
            let offset = pivotOffset
            setFrameOrigin(NSPoint(x: newValue.x - offset.dx, y: newValue.y - offset.dy))
        }
    }

    /// The centre's offset from the frame's origin after the rotation, less
    /// the same offset before it.
    private var pivotOffset: CGVector {
        let (halfWidth, halfHeight) = (frame.width / 2, frame.height / 2)
        let angle = frameRotation.degreesToRadians
        return CGVector(
            dx: halfWidth * cos(angle) - halfHeight * sin(angle) - halfWidth,
            dy: halfWidth * sin(angle) + halfHeight * cos(angle) - halfHeight)
    }

    /// Rotation about the view's centre in degrees, unwrapped: after rotating
    /// to 720 it reads 720, not 0. It is `frameRotation`, which wraps, with
    /// the origin moved so the centre stays put, like `frameCenterRotation`.
    ///
    /// The logical angle is remembered together with the `frameRotation` it
    /// produced. If something else has rotated the view since, the angle is
    /// read back from `frameRotation` instead.
    var rotation: CGFloat {
        get {
            if let state = rotationState, state.frameRotation == frameRotation { return state.degrees }
            return frameRotation
        }
        set {
            let origin = untransformedOrigin
            frameRotation = newValue
            untransformedOrigin = origin
            rotationState = RotationState(degrees: newValue, frameRotation: frameRotation)
        }
    }

    private var rotationState: RotationState? {
        get { objc_getAssociatedObject(self, &rotationStateKey) as? RotationState }
        set { objc_setAssociatedObject(self, &rotationStateKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// `alphaValue`, under UIKit's name, so both platforms share `.alpha`.
    var alpha: CGFloat {
        get { alphaValue }
        set { alphaValue = newValue }
    }
}

/// The last angle Kinieta gave a view, with the `frameRotation` AppKit stored
/// for it, to tell whether it is still current.
private final class RotationState {
    let degrees: CGFloat
    let frameRotation: CGFloat

    init(degrees: CGFloat, frameRotation: CGFloat) {
        self.degrees = degrees
        self.frameRotation = frameRotation
    }
}

nonisolated(unsafe) private var rotationStateKey: UInt8 = 0
#endif
#endif
