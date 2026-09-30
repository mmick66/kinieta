// Kinieta — MIT License. See LICENSE.
//
// Kinieta runs on UIKit (iOS, tvOS, Mac Catalyst, visionOS) and, experimentally,
// on AppKit (native macOS). Sources compile under `canImport(UIKit) || os(macOS)`;
// `os(macOS)` is false under Mac Catalyst, which takes the UIKit path. Every
// property works on both; elsewhere, such as Linux, the module is empty.

#if canImport(UIKit)
import UIKit

/// The view type Kinieta animates on this platform.
typealias PlatformView = UIView

/// The colour type of this platform's views.
typealias PlatformColor = UIColor

/// What a dynamic (light/dark) colour resolves against.
typealias PlatformAppearance = UITraitCollection

extension UITraitCollection {
    /// Whether a dynamic colour can resolve differently against `other`.
    func resolvesColorsDifferently(from other: UITraitCollection) -> Bool {
        hasDifferentColorAppearance(comparedTo: other)
    }
}
#elseif os(macOS)
import AppKit

/// The view type Kinieta animates on this platform.
typealias PlatformView = NSView

/// The colour type of this platform's views.
typealias PlatformColor = NSColor

/// What a dynamic (light/dark) colour resolves against.
typealias PlatformAppearance = NSAppearance

extension NSAppearance {
    /// Whether a dynamic colour can resolve differently against `other`.
    /// Every appearance, the high-contrast ones included, has its own name.
    func resolvesColorsDifferently(from other: NSAppearance) -> Bool {
        name != other.name
    }
}
#endif
