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
        let rgb = ColorMath.extractComponents(of: originalColor)
        #expect(rgb.color() == originalColor)
        #expect(rgb == ColorMath.RGB(red: 237.0 / 255.0, green: 99.0 / 255.0, blue: 102.0 / 255.0, alpha: 1))
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
        let lch = ColorMath.extractComponents(of: originalColor).lch
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
