// Kinieta — MIT License. See LICENSE.
//
// Kinieta runs on UIKit (iOS, tvOS, Mac Catalyst, visionOS) and, experimentally,
// on AppKit (native macOS). Sources compile under `canImport(UIKit) || os(macOS)`;
// `os(macOS)` is false under Mac Catalyst, which takes the UIKit path. On AppKit
// only position, size, rotation and `.alpha` are supported so far. Elsewhere,
// such as Linux, the module is empty.

#if canImport(UIKit)
import UIKit

/// The view type Kinieta animates on this platform.
typealias PlatformView = UIView
#elseif os(macOS)
import AppKit

/// The view type Kinieta animates on this platform.
typealias PlatformView = NSView
#endif
