import Testing
import UIKit
@testable import Kinieta

@MainActor
struct ColorTests {

    let originalColor = UIColor(red: 237.0 / 255.0, green: 99.0 / 255.0, blue: 102.0 / 255.0, alpha: 1.00)

    private func roundTrip(_ space: UIColor.Components.Space) -> UIColor {
        UIColor(components: originalColor.components(as: space))
    }

    private func sameRGB(_ a: UIColor, _ b: UIColor, tolerance: CGFloat = 1e-6) -> Bool {
        let x = a.components(as: .RGB), y = b.components(as: .RGB)
        return approx(x.c1, y.c1, tolerance) && approx(x.c2, y.c2, tolerance)
            && approx(x.c3, y.c3, tolerance) && approx(x.alpha, y.alpha, tolerance)
    }

    @Test func rgbRoundTripIsExact() {
        #expect(originalColor == roundTrip(.RGB))
    }

    @Test func hsbRoundTripIsCloseEnough() {
        #expect(sameRGB(originalColor, roundTrip(.HSB), tolerance: 1e-4))
    }

    @Test func hclRoundTripIsCloseEnough() {
        #expect(sameRGB(originalColor, roundTrip(.HCL), tolerance: 1e-3))
    }

    @Test func hclComponentsMatchReferenceValues() {
        let (h, l, c, a) = originalColor.hlca
        #expect(approx(h * LCHColor.MaxH, 25.63104309046355, 0.05))
        #expect(approx(l * LCHColor.MaxL, 59.78697847134286, 0.05))
        #expect(approx(c * LCHColor.MaxC, 59.360754654915006, 0.05))
        #expect(a == 1.0)
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
