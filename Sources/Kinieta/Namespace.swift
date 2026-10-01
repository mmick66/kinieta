// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit)
import UIKit
#elseif os(macOS)
import AppKit
#endif

#if canImport(UIKit) || os(macOS)

// The module and its main class share the name `Kinieta`, so a client cannot
// write `Kinieta.Property` to mean the module's `Property`: it names a member of
// the class. The nested aliases below make that spelling work. They cannot
// name their targets directly, because inside the class `Property` is the
// alias itself, so they go through these. Not meant to be used directly.
@_documentation(visibility: internal) public typealias _KinietaProperty = Property
@_documentation(visibility: internal) public typealias _KinietaCustomProperty = CustomProperty
@_documentation(visibility: internal) public typealias _KinietaInterpolatable = Interpolatable
@_documentation(visibility: internal) public typealias _KinietaEasing = Easing
@_documentation(visibility: internal) public typealias _KinietaBezier = Bezier
@_documentation(visibility: internal) public typealias _KinietaColorInterpolation = ColorInterpolation
@_documentation(visibility: internal) public typealias _KinietaEngine = Engine
@_documentation(visibility: internal) public typealias _KinietaReduceMotionBehavior = ReduceMotionBehavior
@_documentation(visibility: internal) public typealias _KinietaStep = Step

/// The library's types under the name of the class, so `Kinieta.Property`
/// still means Kinieta's `Property` in a module that declares its own.
extension Kinieta {
    /// A block called on the main actor when an action finishes. Pass one to
    /// `onComplete(_:)` or `Kinieta.group(_:completion:)`.
    public typealias Completion = @MainActor () -> Void

    /// Kinieta's `Property`.
    public typealias Property = _KinietaProperty
    /// Kinieta's `CustomProperty`.
    public typealias CustomProperty = _KinietaCustomProperty
    /// Kinieta's `Interpolatable`.
    public typealias Interpolatable = _KinietaInterpolatable
    /// Kinieta's `Easing`.
    public typealias Easing = _KinietaEasing
    /// Kinieta's `Bezier`.
    public typealias Bezier = _KinietaBezier
    /// Kinieta's `ColorInterpolation`.
    public typealias ColorInterpolation = _KinietaColorInterpolation
    /// Kinieta's `Engine`.
    public typealias Engine = _KinietaEngine
    /// Kinieta's `ReduceMotionBehavior`.
    public typealias ReduceMotionBehavior = _KinietaReduceMotionBehavior
    /// Kinieta's `Step`.
    public typealias Step = _KinietaStep
}

#endif
