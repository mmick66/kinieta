// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit)
import UIKit

public extension UIView {

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

    /// Rotation in degrees. Setting it replaces the transform with a pure rotation.
    var rotation: CGFloat {
        get { atan2(transform.b, transform.a).radiansToDegrees }
        set { transform = CGAffineTransform(rotationAngle: newValue.degreesToRadians) }
    }

    var backgroundColorOrClear: UIColor {
        backgroundColor ?? .clear
    }

    var borderColorOrClear: UIColor {
        layer.borderColor.map { UIColor(cgColor: $0) } ?? .clear
    }
}
#endif
