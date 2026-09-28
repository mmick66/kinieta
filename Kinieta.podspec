Pod::Spec.new do |s|

  s.name         = "Kinieta"
  s.version      = "1.0.0"
  s.summary      = "A timeline animation engine for UIKit with a typed, chainable API. Prefer Swift Package Manager; CocoaPods support ends after 1.1."

  s.description  = <<-DESC
A timeline animation engine for UIKit with a typed, chainable API.

- Timelines. Animations run one after another, side by side, or grouped across views with a single completion.
- Typed properties. .x(250), .background(.systemPink), .rotation(degrees: 30). Wrong types are compile errors.
- Real easing. Cubic Bézier curves with the same semantics as CSS and cubic-bezier.com, plus presets from sine to back.
- Perceptual colour. Colours interpolate through LCH by default, so pink to cyan never passes through grey.
- Handles. Every timeline can be cancelled, paused, resumed or awaited.
- Swift 6, iOS, tvOS and Mac Catalyst 17+. Main-actor isolated, Sendable where it matters, Reduce Motion aware.
                   DESC

  s.homepage     = "https://github.com/mmick66/kinieta"

  s.license      = { :type => "MIT", :file => "LICENSE" }

  s.author       = "Michael Michailidis"

  s.ios.deployment_target  = "17.0"
  s.tvos.deployment_target = "17.0"
  s.swift_versions = ["6.0"]

  s.source       = { :git => "https://github.com/mmick66/kinieta.git", :tag => s.version }

  s.source_files = "Sources/Kinieta/**/*.swift"

  # The same privacy manifest SwiftPM consumers get from Package.swift.
  s.resource_bundles = { "Kinieta_Privacy" => ["Sources/Kinieta/PrivacyInfo.xcprivacy"] }

end