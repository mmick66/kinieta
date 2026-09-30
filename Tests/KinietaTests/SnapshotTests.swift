// The references are only valid on the iOS simulator runtime they were recorded
// on, so this suite does not build for tvOS or run on Mac Catalyst.
#if os(iOS) && !targetEnvironment(macCatalyst)
import SnapshotTesting
import Testing
import UIKit

@testable import Kinieta

/// Visual regression tests. Each animation is driven with synthetic frames to a
/// fixed progress and the resulting view is rendered to an image that is
/// compared against a reference PNG in `__Snapshots__`.
///
/// Record new references with `TEST_RUNNER_SNAPSHOT_TESTING_RECORD=all` in the
/// environment of `xcodebuild test`, then review the images before committing.
///
/// References are recorded on the iPhone 17 Pro simulator running iOS 26.5, the
/// runtime pinned in `.github/workflows/ci.yml` and the README. Other runtimes can
/// render differently enough to fail the 0.98 perceptual precision.
@Suite(.serialized, .usesSharedEngine)
@MainActor
struct SnapshotTests {

    // Tests must not depend on the host's accessibility settings: on Mac Catalyst,
    // UIAccessibility reads the Mac's Reduce Motion switch, which some CI runners have on.
    init() {
        Engine.shared.isReduceMotionEnabled = { false }
    }

    nonisolated static let progressPoints: [CGFloat] = [0, 0.25, 0.5, 0.75, 1]

    struct Case: Sendable {
        let name: String
        let property: Property
    }

    nonisolated static let cases: [Case] = [
        Case(name: "x", property: .x(50)),
        Case(name: "y", property: .y(50)),
        Case(name: "width", property: .width(80)),
        Case(name: "height", property: .height(80)),
        Case(name: "frame", property: .frame(CGRect(x: 30, y: 30, width: 60, height: 60))),
        Case(name: "alpha", property: .alpha(0)),
        Case(name: "rotation", property: .rotation(degrees: 90)),
        Case(name: "background", property: .background(.systemTeal)),
        Case(name: "borderColor", property: .borderColor(.systemIndigo)),
        Case(name: "borderWidth", property: .borderWidth(12)),
        Case(name: "cornerRadius", property: .cornerRadius(20)),
    ]

    /// A 100 by 100 stage with a 40 by 40 pink box near the top-left corner.
    private func stage(_ setup: (UIView) -> Void = { _ in }) -> (stage: UIView, box: UIView) {
        let stage = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        stage.backgroundColor = .systemBackground
        let box = UIView(frame: CGRect(x: 10, y: 10, width: 40, height: 40))
        box.backgroundColor = .systemPink
        box.layer.borderColor = UIColor.systemTeal.cgColor
        box.layer.borderWidth = 2
        box.layer.cornerRadius = 4
        stage.addSubview(box)
        setup(box)
        return (stage, box)
    }

    /// Runs `properties` on `box` over one second and stops at `progress`.
    private func drive(_ box: UIView, _ properties: [Property], to progress: CGFloat, easing: Easing? = nil) {
        let animation = PropertyAnimation(AnimationSpec(box, properties, duration: 1, easing: easing?.bezier))
        var elapsed: CGFloat = 0
        while elapsed < progress {
            _ = animation.update(Engine.Frame(0.25))
            elapsed += 0.25
        }
    }

    private func image(_ style: UIUserInterfaceStyle = .light) -> Snapshotting<UIView, UIImage> {
        .image(perceptualPrecision: 0.98, traits: UITraitCollection(userInterfaceStyle: style))
    }

    @Test(arguments: cases)
    func propertyAtEveryProgressPoint(_ testCase: Case) {
        for progress in Self.progressPoints {
            let (stage, box) = stage()
            drive(box, [testCase.property], to: progress)
            assertSnapshot(of: stage, as: image(), named: "\(testCase.name)-\(Int(progress * 100))")
        }
    }

    @Test func overshootingCurveOnSizeAndPosition() {
        // backInOut dips below the start early and overshoots the end late.
        for progress in [CGFloat(0.25), 0.75] {
            let (stage, box) = stage()
            drive(box, [.x(50), .width(60)], to: progress, easing: .inOut(.back))
            assertSnapshot(of: stage, as: image(), named: "backInOut-\(Int(progress * 100))")
        }
    }

    @Test func frameOnARotatedView() {
        // The box stays rotated about its centre while it moves and grows to the target.
        for progress in Self.progressPoints {
            let (stage, box) = stage { $0.rotation = 30 }
            drive(box, [.frame(CGRect(x: 40, y: 40, width: 50, height: 30))], to: progress)
            assertSnapshot(of: stage, as: image(), named: "rotated-frame-\(Int(progress * 100))")
        }
    }

    @Test func dynamicColoursInDarkAppearance() {
        // The targets are dynamic colours, so the end state must differ between appearances.
        for style in [UIUserInterfaceStyle.light, .dark] {
            for progress in Self.progressPoints {
                // The appearance is set on the view itself, so the frames in between
                // resolve against it rather than the app's traits.
                let (stage, box) = stage { $0.overrideUserInterfaceStyle = style }
                drive(box, [.background(.label), .borderColor(.secondaryLabel)], to: progress)
                let name = style == .dark ? "dark" : "light"
                assertSnapshot(of: stage, as: image(style), named: "dynamic-\(name)-\(Int(progress * 100))")
            }
        }
    }

    @Test func colourPathsAtTheMidpoint() {
        let pink = UIColor(red: 1.00, green: 0.44, blue: 0.75, alpha: 1.00)
        let cyan = UIColor(red: 0.00, green: 0.80, blue: 0.90, alpha: 1.00)
        for (name, mode) in [("rgb", ColorInterpolation.rgb), ("hsb", .hsb), ("lch", .lch)] {
            let (stage, box) = stage { $0.backgroundColor = pink }
            drive(box, [.background(cyan, interpolation: mode)], to: 0.5)
            assertSnapshot(of: stage, as: image(), named: "pink-to-cyan-\(name)")
        }

        let (clearStage, clearBox) = stage { $0.backgroundColor = .clear }
        drive(clearBox, [.background(.systemIndigo)], to: 0.5)
        assertSnapshot(of: clearStage, as: image(), named: "clear-to-indigo-lch")

        let (greyStage, greyBox) = stage { $0.backgroundColor = .gray }
        drive(greyBox, [.background(.systemBlue, interpolation: .hsb)], to: 0.5)
        assertSnapshot(of: greyStage, as: image(), named: "grey-to-blue-hsb")
    }

    @Test func displayP3ColoursAtTheMidpoint() {
        // Between two Display P3 colours the frames stay outside sRGB instead of being clipped to it.
        let red = UIColor(displayP3Red: 1, green: 0, blue: 0, alpha: 1)
        let green = UIColor(displayP3Red: 0, green: 1, blue: 0, alpha: 1)
        for (name, mode) in [("rgb", ColorInterpolation.rgb), ("hsb", .hsb), ("lch", .lch)] {
            let (stage, box) = stage { $0.backgroundColor = red }
            drive(box, [.background(green, interpolation: mode)], to: 0.5)
            assertSnapshot(of: stage, as: image(), named: "p3-red-to-green-\(name)")
        }
    }
}
#endif
