// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit)
import UIKit
import os

/// A property Kinieta has no case for: a key path or a constraint constant.
///
/// Make one with ``Property/custom(_:to:isMotion:)-(ReferenceWritableKeyPath<UIView,Value>,_,_)``
/// or ``Property/constant(_:to:)``; it has no public members.
///
/// Unchecked `Sendable`: every stored value is immutable, and the key path or
/// constraint it captures is only read and written on the main actor, when
/// the animation runs.
public struct CustomProperty: @unchecked Sendable {

    /// Builds the per-frame transformation from the view's current value, or
    /// `nil` when there is nothing to animate. Takes the engine's default
    /// colour interpolation.
    typealias Builder = @MainActor (UIView, ColorInterpolation) -> Property.Transformation?

    /// The key path or the constraint's `ObjectIdentifier`, as a `.custom`
    /// key, or `.transform` for a key path to the view's `transform`.
    let key: Property.Key
    let name: String
    let isMotion: Bool
    /// The object written when it is not the view: a constraint's identity.
    /// A newer animation of the same key on this object takes it over,
    /// whichever view's timeline runs it.
    let target: ObjectIdentifier?
    let transformation: Builder

    init(
        key: Property.Key, name: String, isMotion: Bool, target: ObjectIdentifier? = nil,
        transformation: @escaping Builder
    ) {
        self.key = key
        self.name = name
        self.isMotion = isMotion
        self.target = target
        self.transformation = transformation
    }

    fileprivate static let logger = Logger(subsystem: "Kinieta", category: "Property")
}

public extension Property {

    /// Animates any writable key path of the view to `value`.
    ///
    /// ```swift
    /// view.animate(.custom(\.layer.shadowOpacity, to: 0.4), duration: 0.3)
    /// ```
    ///
    /// The starting value is read when the animation starts. `UIColor` and
    /// `CGColor` values interpolate like ``background(_:interpolation:)``:
    /// through `Engine.shared.colorInterpolation`, resolved against the view's
    /// traits. A `CGAffineTransform`, such as `\.transform`, is decomposed
    /// and rotates the shorter way round; see
    /// ``Interpolatable/interpolated(to:progress:)``.
    ///
    /// - Parameters:
    ///   - keyPath: The property to animate, such as `\.layer.shadowOpacity`.
    ///   - value: The value to animate to.
    ///   - isMotion: Whether the value moves, resizes, rotates or scales
    ///     something, so it snaps under Reduce Motion like `.x` or `.rotation`
    ///     do. By default a `CGAffineTransform` does and anything else
    ///     animates like a fade.
    @MainActor
    static func custom<Value: Interpolatable>(
        _ keyPath: ReferenceWritableKeyPath<UIView, Value>, to value: Value, isMotion: Bool? = nil
    ) -> Property {
        custom(keyPath: keyPath, to: value, isMotion: isMotion)
    }

    /// Animates a writable key path of a `UIView` subclass to `value`.
    ///
    /// ```swift
    /// label.animate(.custom(\UILabel.textColor, to: .systemPink), duration: 0.5)
    /// ```
    ///
    /// On a view that is not a `Root`, the property does nothing and logs a warning.
    ///
    /// - Parameters:
    ///   - keyPath: The property to animate, rooted in the subclass, such as `\UILabel.textColor`.
    ///   - value: The value to animate to.
    ///   - isMotion: Whether the value moves, resizes, rotates or scales
    ///     something, so it snaps under Reduce Motion. By default a
    ///     `CGAffineTransform` does and anything else animates like a fade.
    @MainActor
    static func custom<Root: UIView, Value: Interpolatable>(
        _ keyPath: ReferenceWritableKeyPath<Root, Value>, to value: Value, isMotion: Bool? = nil
    ) -> Property {
        custom(keyPath: keyPath, to: value, isMotion: isMotion)
    }

    /// Animates an optional key path of the view, such as `tintColor`, to `value`.
    ///
    /// When the current value is `nil`, a colour fades in from clear and any
    /// other value switches to `value` as soon as the animation starts.
    @MainActor
    static func custom<Value: Interpolatable>(
        _ keyPath: ReferenceWritableKeyPath<UIView, Value?>, to value: Value, isMotion: Bool? = nil
    ) -> Property {
        custom(keyPath: keyPath, to: value, isMotion: isMotion)
    }

    /// Animates an optional key path of a `UIView` subclass, such as a label's
    /// `textColor`, to `value`.
    ///
    /// When the current value is `nil`, a colour fades in from clear and any
    /// other value switches to `value` as soon as the animation starts.
    @MainActor
    static func custom<Root: UIView, Value: Interpolatable>(
        _ keyPath: ReferenceWritableKeyPath<Root, Value?>, to value: Value, isMotion: Bool? = nil
    ) -> Property {
        custom(keyPath: keyPath, to: value, isMotion: isMotion)
    }

    /// Animates an Auto Layout constraint's `constant`, laying out the
    /// constraint's views on every frame.
    ///
    /// ```swift
    /// badge.animate(.constant(badgeLeading, to: 120), duration: 0.5)
    /// ```
    ///
    /// Unlike `.x` or `.frame`, the change survives the next layout pass, so a
    /// view positioned by constraints stays where the animation leaves it
    /// through rotation, size class changes and the keyboard.
    ///
    /// Each frame calls `layoutIfNeeded()` on the nearest common superview of
    /// the constraint's items: for a constraint between siblings their
    /// superview, for one between a view and its ancestor that ancestor, and
    /// for a width or height constraint the view's superview. A deactivated
    /// constraint still animates its constant.
    ///
    /// The constraint is held weakly, and counts as motion: it snaps under
    /// Reduce Motion.
    @MainActor
    static func constant(_ constraint: NSLayoutConstraint, to value: CGFloat) -> Property {
        let identifier = ObjectIdentifier(constraint)
        let name = "constant(\(constraint.identifier ?? "\(identifier)"))"
        return .extended(
            CustomProperty(key: .custom(identifier), name: name, isMotion: true, target: identifier) {
                [weak constraint] _, _ in
                guard let constraint else { return nil }
                let from = constraint.constant
                let container = constraint.layoutContainer
                return { [weak constraint, weak container] _, factor in
                    constraint?.constant = from.interpolated(to: value, progress: factor)
                    // Outside a window a new constant does not mark the container for layout.
                    container?.setNeedsLayout()
                    container?.layoutIfNeeded()
                }
            })
    }
}

extension Property {

    @MainActor
    fileprivate static func custom<Root: UIView, Value: Interpolatable>(
        keyPath: ReferenceWritableKeyPath<Root, Value>, to value: Value, isMotion: Bool?
    ) -> Property {
        let name = String(describing: keyPath)
        // `\UIImageView.transform` is a different key path from `\UIView.transform`
        // but writes the same property, which `.rotation` writes too.
        let key: Key = keyPath == \Root.transform ? .transform : .custom(keyPath)
        return .extended(
            CustomProperty(key: key, name: name, isMotion: isMotion ?? Value.isMotion) { view, colorMode in
                guard let root = view.as(Root.self, for: name) else { return nil }
                let values = interpolator(
                    from: root[keyPath: keyPath], to: value, colorMode: colorMode, view: view, name: name)
                return { view, factor in (view as? Root)?[keyPath: keyPath] = values(factor) }
            })
    }

    @MainActor
    fileprivate static func custom<Root: UIView, Value: Interpolatable>(
        keyPath: ReferenceWritableKeyPath<Root, Value?>, to value: Value, isMotion: Bool?
    ) -> Property {
        let name = String(describing: keyPath)
        return .extended(
            CustomProperty(key: .custom(keyPath), name: name, isMotion: isMotion ?? Value.isMotion) { view, colorMode in
                guard let root = view.as(Root.self, for: name) else { return nil }
                guard let from = root[keyPath: keyPath] ?? Value.clear else {
                    return { view, factor in if factor > 0 { (view as? Root)?[keyPath: keyPath] = value } }
                }
                let values = interpolator(from: from, to: value, colorMode: colorMode, view: view, name: name)
                return { view, factor in (view as? Root)?[keyPath: keyPath] = values(factor) }
            })
    }

    /// Colours take the engine's colour interpolation and the view's traits,
    /// like `.background`; every other value its own `interpolated(to:progress:)`.
    @MainActor
    private static func interpolator<Value: Interpolatable>(
        from: Value, to: Value, colorMode: ColorInterpolation, view: UIView, name: String
    ) -> (CGFloat) -> Value {
        if let source = from as? UIColor, let target = to as? UIColor {
            let colors = colorInterpolator(from: source, to: target, mode: colorMode, view: view, name: name)
            return { factor in colors(factor) as? Value ?? from.interpolated(to: to, progress: factor) }
        }
        if Value.self == CGColor.self {
            // Checked by type: a CoreFoundation cast from `Value` always succeeds.
            let source = from as! CGColor, target = to as! CGColor
            let colors = colorInterpolator(
                from: UIColor(cgColor: source), to: UIColor(cgColor: target), mode: colorMode, view: view, name: name)
            return { factor in
                // The ends as given, not a copy made through `UIColor`.
                if factor <= 0 { return from }
                if factor >= 1 { return to }
                return colors(factor).cgColor as! Value
            }
        }
        return { factor in from.interpolated(to: to, progress: factor) }
    }
}

extension Interpolatable {
    /// Whether a `.custom` key path of this type counts as motion by default:
    /// a transform moves, rotates or scales the view; other values fade.
    fileprivate static var isMotion: Bool { self == CGAffineTransform.self }

    /// The value an optional colour key path starts from when it is `nil`.
    fileprivate static var clear: Self? {
        if self == UIColor.self { return UIColor.clear as? Self }
        if self == CGColor.self { return UIColor.clear.cgColor as? Self }
        return nil
    }
}

extension UIView {
    /// This view as a `Root`, or `nil` with a warning naming the property.
    fileprivate func `as`<Root: UIView>(_ type: Root.Type, for name: String) -> Root? {
        if let root = self as? Root { return root }
        CustomProperty.logger.warning(
            "\(name, privacy: .public) needs a \(Root.self, privacy: .public), not a \(Self.self, privacy: .public); ignoring it"
        )
        return nil
    }
}

extension NSLayoutConstraint {

    /// The view to lay out after changing the constant: the nearest common
    /// superview of the items, or the superview of a single item.
    var layoutContainer: UIView? {
        let views = [firstItem, secondItem].compactMap { item -> UIView? in
            (item as? UIView) ?? (item as? UILayoutGuide)?.owningView
        }
        guard let first = views.first else { return nil }
        guard views.count == 2, views[0] !== views[1] else { return first.superview ?? first }
        let second = views[1]
        var ancestor: UIView? = first
        while let candidate = ancestor, !second.isDescendant(of: candidate) { ancestor = candidate.superview }
        return ancestor
    }
}
#endif
