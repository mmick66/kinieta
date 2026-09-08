// Kinieta — MIT License. See LICENSE.

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

extension UIView {

    var x: CGFloat {
        get { frame.origin.x }
        set { frame.origin.x = newValue }
    }

    var y: CGFloat {
        get { frame.origin.y }
        set { frame.origin.y = newValue }
    }

    var width: CGFloat {
        get { frame.size.width }
        set { frame.size.width = newValue }
    }

    var height: CGFloat {
        get { frame.size.height }
        set { frame.size.height = newValue }
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
