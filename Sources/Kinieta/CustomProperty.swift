// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit)
import UIKit
#elseif os(macOS)
import AppKit
#endif

#if canImport(UIKit) || os(macOS)
import os

/// A property Kinieta has no case for: a key path or a constraint constant.
///
/// Make one with ``Property/custom(_:to:isMotion:)-(ReferenceWritableKeyPath<Root,Value>,_,_)``
/// or ``Property/constant(of:to:)``; it has no public members.
///
/// Internally it describes every property, built-in cases included: what the
/// property writes, whether it is motion, and how to build its per-frame
/// transformation. See `Property.descriptor`.
///
/// Unchecked `Sendable`: every stored value is immutable, and the key path or
/// constraint it captures is only read and written on the main actor, when
/// the animation runs.
public struct CustomProperty: @unchecked Sendable {

    /// Builds the per-frame transformation from the view's current value, or
    /// `nil` when there is nothing to animate. Takes the engine's default
    /// colour interpolation.
    typealias Builder = @MainActor (PlatformView, ColorInterpolation) -> Property.Transformation?

    /// The key path or the constraint's `ObjectIdentifier`, as a `.custom`
    /// key, or `.transform` for a key path to what `.rotation` writes: the
    /// view's `transform`, or its `frameRotation` on AppKit.
    let key: Property.Key
    let name: String
    let isMotion: Bool
    /// The object written when it is not the view: a constraint's identity.
    /// A newer animation of the same key on this object takes it over,
    /// whichever view's timeline runs it.
    let target: ObjectIdentifier?
    /// The properties written together under one `key`, each of which a newer
    /// animation can take over on its own: the sides of a `.frame`. Empty for
    /// a property that writes its `key` alone.
    let parts: [CustomProperty]
    /// The keys the property writes, each of which a newer animation can take
    /// over on its own: the parts' keys, or `key` alone. `.frame` writes
    /// position and size as `.x`, `.y`, `.width` and `.height`, so a later
    /// `.x` takes only the position.
    let keys: [Property.Key]
    let builder: Builder

    init(
        key: Property.Key, name: String, isMotion: Bool, target: ObjectIdentifier? = nil,
        builder: @escaping Builder
    ) {
        self.key = key
        self.name = name
        self.isMotion = isMotion
        self.target = target
        self.parts = []
        self.keys = [key]
        self.builder = builder
    }

    /// A property that writes `parts` together, in order.
    init(key: Property.Key, name: String, isMotion: Bool, parts: [CustomProperty]) {
        self.key = key
        self.name = name
        self.isMotion = isMotion
        self.target = nil
        self.parts = parts
        self.keys = parts.map(\.key)
        self.builder = { view, colorMode in
            let transformations = parts.map { $0.transformation(for: view, defaultColorInterpolation: colorMode) }
            return { view, factor in
                for transformation in transformations { transformation(view, factor) }
            }
        }
    }

    /// The object whose `keys` the property writes: the view, or the
    /// constraint of a `.constant`, which any view's timeline can animate.
    @MainActor
    func owner(on view: PlatformView) -> ObjectIdentifier {
        target ?? ObjectIdentifier(view)
    }

    /// Builds the per-frame transformation, capturing the view's current value
    /// as the starting point; one that does nothing when there is nothing to animate.
    @MainActor
    func transformation(for view: PlatformView, defaultColorInterpolation: ColorInterpolation)
        -> Property.Transformation
    {
        builder(view, defaultColorInterpolation) ?? { _, _ in }
    }

    /// One transformation per key in `keys`, in the same order.
    @MainActor
    func transformations(for view: PlatformView, defaultColorInterpolation: ColorInterpolation)
        -> [Property.Transformation]
    {
        guard !parts.isEmpty else {
            return [transformation(for: view, defaultColorInterpolation: defaultColorInterpolation)]
        }
        return parts.map { $0.transformation(for: view, defaultColorInterpolation: defaultColorInterpolation) }
    }

    fileprivate static let logger = Logger(subsystem: "Kinieta", category: "Property")
}

public extension Property {

    // The view type differs by platform; a doc comment must sit inside the `#if` to attach.
    #if canImport(UIKit)
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

    #else
    /// Animates any writable key path of the view to `value`.
    ///
    /// ```swift
    /// view.animate(.custom(\.layer!.shadowOpacity, to: 0.4), duration: 0.3)
    /// ```
    ///
    /// The starting value is read when the animation starts. `NSColor` and
    /// `CGColor` values interpolate like ``background(_:interpolation:)``:
    /// through `Engine.shared.colorInterpolation`, resolved against the view's
    /// effective appearance. A key path to `frameRotation` or
    /// `frameCenterRotation` writes what ``rotation(degrees:)`` writes, so
    /// each takes the other over.
    ///
    /// - Parameters:
    ///   - keyPath: The property to animate, such as `\.layer!.shadowOpacity`.
    ///   - value: The value to animate to.
    ///   - isMotion: Whether the value moves, resizes, rotates or scales
    ///     something, so it snaps under Reduce Motion like `.x` or `.rotation`
    ///     do. By default a key path to the view's rotation or to a
    ///     `CGAffineTransform` does and anything else animates like a fade.
    @MainActor
    static func custom<Value: Interpolatable>(
        _ keyPath: ReferenceWritableKeyPath<NSView, Value>, to value: Value, isMotion: Bool? = nil
    ) -> Property {
        custom(keyPath: keyPath, to: value, isMotion: isMotion)
    }

    /// Animates a writable key path of an `NSView` subclass to `value`.
    ///
    /// ```swift
    /// box.animate(.custom(\NSBox.fillColor, to: .systemPink), duration: 0.5)
    /// ```
    ///
    /// On a view that is not a `Root`, the property does nothing and logs a warning.
    ///
    /// - Parameters:
    ///   - keyPath: The property to animate, rooted in the subclass, such as `\NSBox.fillColor`.
    ///   - value: The value to animate to.
    ///   - isMotion: Whether the value moves, resizes, rotates or scales
    ///     something, so it snaps under Reduce Motion. By default a key path
    ///     to the view's rotation or to a `CGAffineTransform` does and
    ///     anything else animates like a fade.
    @MainActor
    static func custom<Root: NSView, Value: Interpolatable>(
        _ keyPath: ReferenceWritableKeyPath<Root, Value>, to value: Value, isMotion: Bool? = nil
    ) -> Property {
        custom(keyPath: keyPath, to: value, isMotion: isMotion)
    }

    /// Animates an optional key path of the view, such as its layer's
    /// `shadowColor`, to `value`.
    ///
    /// When the current value is `nil`, a colour fades in from clear and any
    /// other value switches to `value` as soon as the animation starts.
    @MainActor
    static func custom<Value: Interpolatable>(
        _ keyPath: ReferenceWritableKeyPath<NSView, Value?>, to value: Value, isMotion: Bool? = nil
    ) -> Property {
        custom(keyPath: keyPath, to: value, isMotion: isMotion)
    }

    /// Animates an optional key path of an `NSView` subclass, such as a text
    /// field's `textColor`, to `value`.
    ///
    /// When the current value is `nil`, a colour fades in from clear and any
    /// other value switches to `value` as soon as the animation starts.
    @MainActor
    static func custom<Root: NSView, Value: Interpolatable>(
        _ keyPath: ReferenceWritableKeyPath<Root, Value?>, to value: Value, isMotion: Bool? = nil
    ) -> Property {
        custom(keyPath: keyPath, to: value, isMotion: isMotion)
    }
    #endif

    /// Animates an Auto Layout constraint's `constant`, laying out the
    /// constraint's views on every frame.
    ///
    /// ```swift
    /// badge.animate(.constant(of: badgeLeading, to: 120), duration: 0.5)
    /// ```
    ///
    /// Unlike `.x` or `.frame`, the change survives the next layout pass, so a
    /// view positioned by constraints stays where the animation leaves it
    /// through rotation, size class changes and the keyboard.
    ///
    /// Each frame calls `layoutIfNeeded()`, or `layoutSubtreeIfNeeded()` on
    /// AppKit, on the nearest common superview of the constraint's items: for
    /// a constraint between siblings their superview, for one between a view
    /// and its ancestor that ancestor, and for a width or height constraint
    /// the view's superview. A deactivated constraint still animates its constant.
    ///
    /// The constraint is held weakly, and counts as motion: it snaps under
    /// Reduce Motion.
    @MainActor
    static func constant(of constraint: NSLayoutConstraint, to value: CGFloat) -> Property {
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
                    #if canImport(UIKit)
                    container?.setNeedsLayout()
                    container?.layoutIfNeeded()
                    #else
                    container?.needsLayout = true
                    container?.layoutSubtreeIfNeeded()
                    #endif
                }
            })
    }
}

extension Property {

    @MainActor
    fileprivate static func custom<Root: PlatformView, Value: Interpolatable>(
        keyPath: ReferenceWritableKeyPath<Root, Value>, to value: Value, isMotion: Bool?
    ) -> Property {
        let name = String(describing: keyPath)
        let key: Key = writesRotation(keyPath) ? .transform : .custom(keyPath)
        return .extended(
            CustomProperty(key: key, name: name, isMotion: isMotion ?? (key == .transform || Value.isMotion)) {
                view, colorMode in
                guard let root = view.as(Root.self, for: name) else { return nil }
                let values = interpolator(
                    from: root[keyPath: keyPath], to: value, colorMode: colorMode, view: view, name: name)
                return { view, factor in (view as? Root)?[keyPath: keyPath] = values(factor) }
            })
    }

    @MainActor
    fileprivate static func custom<Root: PlatformView, Value: Interpolatable>(
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

    /// Whether `keyPath` writes what `.rotation` writes, so each takes the other over.
    @MainActor
    private static func writesRotation<Root: PlatformView, Value>(_ keyPath: ReferenceWritableKeyPath<Root, Value>)
        -> Bool
    {
        #if canImport(UIKit)
        // `\UIImageView.transform` is a different key path from `\UIView.transform`
        // but writes the same property.
        return keyPath == \Root.transform
        #else
        return keyPath == \Root.frameRotation || keyPath == \Root.frameCenterRotation
        #endif
    }

    /// Colours take the engine's colour interpolation and the view's traits,
    /// or appearance on AppKit, like `.background`; every other value its own
    /// `interpolated(to:progress:)`.
    @MainActor
    private static func interpolator<Value: Interpolatable>(
        from: Value, to: Value, colorMode: ColorInterpolation, view: PlatformView, name: String
    ) -> (CGFloat) -> Value {
        if let source = from as? PlatformColor, let target = to as? PlatformColor {
            let colors = colorInterpolator(from: source, to: target, mode: colorMode, view: view, name: name)
            return { factor in colors(factor) as? Value ?? from.interpolated(to: to, progress: factor) }
        }
        // Checked by type: a CoreFoundation cast from `Value` always succeeds.
        if Value.self == CGColor.self, let source = platformColor(from as! CGColor),
            let target = platformColor(to as! CGColor)
        {
            let colors = colorInterpolator(from: source, to: target, mode: colorMode, view: view, name: name)
            return { factor in
                // The ends as given, not a copy made through `UIColor` or `NSColor`.
                if factor <= 0 { return from }
                if factor >= 1 { return to }
                return colors(factor).cgColor as! Value
            }
        }
        return { factor in from.interpolated(to: to, progress: factor) }
    }

    /// `color` as a `UIColor`, or an `NSColor` if AppKit can represent it.
    private static func platformColor(_ color: CGColor) -> PlatformColor? {
        #if canImport(UIKit)
        UIColor(cgColor: color)
        #else
        NSColor(cgColor: color)
        #endif
    }
}

extension Interpolatable {
    /// Whether a `.custom` key path of this type counts as motion by default:
    /// a transform moves, rotates or scales the view; other values fade.
    fileprivate static var isMotion: Bool { self == CGAffineTransform.self }

    /// The value an optional colour key path starts from when it is `nil`.
    fileprivate static var clear: Self? {
        if self == PlatformColor.self { return PlatformColor.clear as? Self }
        if self == CGColor.self { return PlatformColor.clear.cgColor as? Self }
        return nil
    }
}

extension PlatformView {
    /// This view as a `Root`, or `nil` with a warning naming the property.
    fileprivate func `as`<Root: PlatformView>(_ type: Root.Type, for name: String) -> Root? {
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
    @MainActor
    var layoutContainer: PlatformView? {
        let views = [firstItem, secondItem].compactMap { item -> PlatformView? in
            #if canImport(UIKit)
            (item as? UIView) ?? (item as? UILayoutGuide)?.owningView
            #else
            (item as? NSView) ?? (item as? NSLayoutGuide)?.owningView
            #endif
        }
        guard let first = views.first else { return nil }
        guard views.count == 2, views[0] !== views[1] else { return first.superview ?? first }
        let second = views[1]
        var ancestor: PlatformView? = first
        while let candidate = ancestor, !second.isDescendant(of: candidate) { ancestor = candidate.superview }
        return ancestor
    }
}
#endif
