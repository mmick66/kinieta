#if canImport(UIKit)
import Testing
import UIKit

@testable import Kinieta

@MainActor
struct ColorTests {

    let originalColor = UIColor(red: 237.0 / 255.0, green: 99.0 / 255.0, blue: 102.0 / 255.0, alpha: 1.00)

    /// Every channel from 0 to 1 in eighths, with a half-transparent alpha.
    private var grid: [ColorMath.RGB] {
        let steps = (0...8).map { CGFloat($0) / 8 }
        return steps.flatMap { r in
            steps.flatMap { g in steps.map { b in ColorMath.RGB(red: r, green: g, blue: b, alpha: 0.5) } }
        }
    }

    private func same(_ a: ColorMath.RGB, _ b: ColorMath.RGB, tolerance: CGFloat) -> Bool {
        approx(a.red, b.red, tolerance) && approx(a.green, b.green, tolerance)
            && approx(a.blue, b.blue, tolerance) && approx(a.alpha, b.alpha, tolerance)
    }

    @Test func extractingComponentsIsExact() {
        let rgb = ColorMath.extractComponents(of: originalColor)!
        #expect(rgb.color() == originalColor)
        #expect(rgb == ColorMath.RGB(red: 237.0 / 255.0, green: 99.0 / 255.0, blue: 102.0 / 255.0, alpha: 1))
    }

    @Test func extractingConvertsOtherColourSpaces() {
        let cmyk = UIColor(cgColor: CGColor(colorSpace: CGColorSpaceCreateDeviceCMYK(), components: [0, 1, 1, 0, 1])!)
        let rgb = ColorMath.extractComponents(of: cmyk)
        #expect(rgb != nil)
        if let rgb { #expect(rgb.red > 0.8 && rgb.green < 0.3 && rgb.blue < 0.3 && rgb.alpha == 1, "\(rgb)") }
    }

    @Test func extractingAPatternGivesNothing() {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { _ in }
        #expect(ColorMath.extractComponents(of: UIColor(patternImage: image)) == nil)
    }

    @Test func hsbRoundTripIsCloseEnough() {
        for rgb in grid { #expect(same(rgb.hsb.rgb, rgb, tolerance: 1e-9), "\(rgb)") }
    }

    @Test func hsbMatchesUIKit() {
        for rgb in grid {
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            rgb.color().getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            let hsb = rgb.hsb
            #expect(approx(hsb.hue / 360, h, 1e-6) && approx(hsb.saturation, s, 1e-6), "\(rgb)")
            #expect(approx(hsb.brightness, b, 1e-6) && hsb.alpha == a, "\(rgb)")
        }
    }

    @Test func lchRoundTripIsCloseEnough() {
        // The sRGB matrices are published to seven digits: about 2e-6 of drift, far below one 8-bit step.
        for rgb in grid { #expect(same(rgb.lch.rgb, rgb, tolerance: 1e-5), "\(rgb)") }
    }

    @Test func transferFunctionRoundTripsThroughLinearLight() {
        for v in stride(from: CGFloat(-1), through: 2, by: 0.01) {
            #expect(approx(ColorMath.gammaEncoded(ColorMath.linearized(v)), v, 1e-12), "\(v)")
        }
    }

    @Test func labSegmentsMeetAtEpsilon() {
        // With the exact CIE constants both branches of f(t) agree at ε.
        let e = ColorMath.labEpsilon
        #expect(approx(cbrt(e), (ColorMath.labKappa * e + 16) / 116, 1e-12))
    }

    @Test func whiteAndBlackSitAtTheEndsOfLightness() {
        let white = ColorMath.RGB(red: 1, green: 1, blue: 1, alpha: 1).lch
        let black = ColorMath.RGB(red: 0, green: 0, blue: 0, alpha: 1).lch
        #expect(approx(white.lightness, 100, 1e-4) && white.chroma < 1e-3)
        #expect(approx(black.lightness, 0, 1e-9) && black.chroma < 1e-9)
    }

    @Test func lchComponentsMatchReferenceValues() {
        let lch = ColorMath.extractComponents(of: originalColor)!.lch
        #expect(approx(lch.hue, 25.63104309046355, 0.05))
        #expect(approx(lch.lightness, 59.78697847134286, 0.05))
        #expect(approx(lch.chroma, 59.360754654915006, 0.05))
        #expect(lch.alpha == 1.0)
    }

    @Test func hueTakesTheShorterArc() {
        #expect(approx(ColorMath.lerpHue(350, 10, 0.5), 0, 1e-9))
        #expect(approx(ColorMath.lerpHue(10, 350, 0.25), 5, 1e-9))
        #expect(approx(ColorMath.lerpHue(90, 180, 0.5), 135, 1e-9))
    }

    @Test func dynamicColoursResolveAgainstTheViewsTraits() {
        // A dark view in a light app: .label is white for the view, black for the app.
        let view = UIView()
        view.overrideUserInterfaceStyle = .dark
        view.backgroundColor = .white
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            let step = Property.background(.label).transformation(for: view, defaultColorInterpolation: .lch)
            step(view, 0.5)
            let mid = ColorMath.extractComponents(of: view.backgroundColor!)!
            #expect(mid.red > 0.95 && mid.green > 0.95 && mid.blue > 0.95, "\(mid)")
            // The end state is still the dynamic colour, not the dark variant.
            step(view, 1)
            let light = UITraitCollection(userInterfaceStyle: .light)
            #expect(view.backgroundColor?.resolvedColor(with: light) == UIColor.label.resolvedColor(with: light))
        }
    }

    @Test func dynamicColoursFollowAnAppearanceChangeMidAnimation() {
        // .label is black in light and white in dark; from a grey the midpoint shows which one is in use.
        let view = UIView()
        view.overrideUserInterfaceStyle = .light
        view.backgroundColor = .gray
        let step = Property.background(.label, interpolation: .rgb).transformation(
            for: view, defaultColorInterpolation: .lch)
        step(view, 0.5)
        let light = ColorMath.extractComponents(of: view.backgroundColor!)!
        #expect(light.red < 0.3, "\(light)")

        view.overrideUserInterfaceStyle = .dark
        step(view, 0.5)
        let dark = ColorMath.extractComponents(of: view.backgroundColor!)!
        #expect(dark.red > 0.7, "\(dark)")

        view.overrideUserInterfaceStyle = .light
        step(view, 0.5)
        #expect(ColorMath.extractComponents(of: view.backgroundColor!)! == light)
    }

    @Test func displayP3RoundTripIsCloseEnough() {
        for rgb in grid { #expect(same(rgb.displayP3.fromDisplayP3, rgb, tolerance: 1e-6), "\(rgb)") }
    }

    /// UIKit converts in single precision with the ICC profile's rounded matrices: up to about 4e-4 off.
    @Test func displayP3MatchesUIKit() {
        for p3 in grid {
            let color = UIColor(displayP3Red: p3.red, green: p3.green, blue: p3.blue, alpha: p3.alpha)
            let extended = ColorMath.extractComponents(of: color)!
            #expect(same(p3.fromDisplayP3, extended, tolerance: ColorMath.Gamut.tolerance), "\(p3)")
        }
    }

    @Test func theGamutIsTheSmallestThatHoldsBothEnds() {
        let pink = ColorMath.RGB(red: 1, green: 0.44, blue: 0.75, alpha: 1)
        let p3Red = ColorMath.extractComponents(of: UIColor(displayP3Red: 1, green: 0, blue: 0, alpha: 1))!
        let beyondP3 = ColorMath.RGB(red: -0.5, green: 1.2, blue: -0.5, alpha: 1)
        #expect(ColorMath.Gamut.smallest(containing: pink, .init(red: 0, green: 0, blue: 0, alpha: 0)) == .sRGB)
        #expect(ColorMath.Gamut.smallest(containing: pink, p3Red) == .displayP3)
        #expect(ColorMath.Gamut.smallest(containing: p3Red, beyondP3) == .extended)
        // Clipping to Display P3 keeps a P3 colour as it is.
        #expect(same(ColorMath.Gamut.displayP3.clip(p3Red), p3Red, tolerance: 1e-4))
    }

    /// The extended-sRGB colour `mode` gives at `progress` from `from` to `to`.
    private func colour(from: UIColor, to: UIColor, _ mode: ColorInterpolation, at progress: CGFloat) -> ColorMath.RGB {
        let view = UIView()
        view.backgroundColor = from
        Property.background(to, interpolation: mode).transformation(for: view, defaultColorInterpolation: .lch)(
            view, progress)
        return ColorMath.extractComponents(of: view.backgroundColor!)!
    }

    @Test(arguments: [ColorInterpolation.rgb, .hsb, .lch])
    func displayP3ColoursStayWideOnTheWay(_ mode: ColorInterpolation) {
        let red = UIColor(displayP3Red: 1, green: 0, blue: 0, alpha: 1)
        let green = UIColor(displayP3Red: 0, green: 1, blue: 0, alpha: 1)
        let tolerance = ColorMath.Gamut.tolerance

        let mid = colour(from: red, to: green, mode, at: 0.5)
        #expect(!mid.isInUnitRange(tolerance: tolerance), "the midpoint is clipped to sRGB: \(mid)")
        #expect(mid.displayP3.isInUnitRange(tolerance: tolerance), "the midpoint is outside Display P3: \(mid)")

        // Just before the end the colour is already the target, so the last frame does not pop.
        let target = ColorMath.extractComponents(of: green)!
        let nearEnd = colour(from: red, to: green, mode, at: 0.999)
        #expect(same(nearEnd, target, tolerance: 0.01), "\(nearEnd) vs \(target)")
    }

    @Test(arguments: [ColorInterpolation.rgb, .hsb, .lch])
    func sRGBColoursStayInSRGBOnTheWay(_ mode: ColorInterpolation) {
        let pink = UIColor(red: 1.00, green: 0.44, blue: 0.75, alpha: 1.00)
        let cyan = UIColor(red: 0.00, green: 0.80, blue: 0.90, alpha: 1.00)
        for progress in stride(from: CGFloat(0.1), to: 1, by: 0.1) {
            let rgb = colour(from: pink, to: cyan, mode, at: progress)
            #expect(rgb.isInUnitRange(tolerance: 0), "\(progress): \(rgb)")
        }
    }

    @Test func rotationSetterMatchesCGAffineTransform() {
        let angle: CGFloat = 30.0
        let v = UIView()
        v.rotation = angle
        let t = CGAffineTransform(rotationAngle: angle.degreesToRadians)
        #expect(v.transform.a == t.a)
        #expect(v.transform.b == t.b)
        #expect(v.transform.c == t.c)
        #expect(v.transform.d == t.d)
    }
}
#endif
