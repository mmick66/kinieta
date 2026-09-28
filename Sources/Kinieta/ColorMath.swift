// Kinieta — MIT License. See LICENSE.
//
// The sRGB matrices and the Lab/LCH structure follow Tim Wood's ColorSpaces
// (https://github.com/timrwood/ColorSpaces, MIT) and Bruce Lindbloom's tables.

#if canImport(UIKit)
import UIKit

/// The colour arithmetic behind colour interpolation, in one place:
/// sRGB ⇄ linear sRGB ⇄ CIE XYZ (D65) ⇄ CIE Lab ⇄ CIE LCh, and sRGB ⇄ HSB.
///
/// Colours enter through ``extractComponents(of:)`` and leave through
/// ``RGB/color``. Every hue is in degrees, 0..<360.
enum ColorMath {

    // MARK: Constants

    /// CIE ε, 216/24389: below it Lab switches to its linear segment.
    static let labEpsilon: CGFloat = 216 / 24389
    /// CIE κ, 24389/27.
    static let labKappa: CGFloat = 24389 / 27
    /// The D65 reference white, Y normalised to 1.
    static let whitePoint = XYZ(x: 0.950_47, y: 1, z: 1.088_83)

    // MARK: Entry point

    /// The gamma-encoded sRGB components of a colour. Wide-gamut colours come
    /// back in extended range, outside 0...1.
    ///
    /// UIKit converts CMYK, Lab and XYZ colours itself. `nil` when a colour
    /// has no RGB equivalent, such as a pattern image.
    static func extractComponents(of color: UIColor) -> RGB? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return RGB(red: red, green: green, blue: blue, alpha: alpha)
    }

    // MARK: Transfer functions and helpers

    /// The sRGB transfer function, from gamma-encoded to linear light.
    /// Mirrored around zero so extended-range values survive.
    static func linearized(_ v: CGFloat) -> CGFloat {
        let m = abs(v)
        let out = m > 0.040_45 ? pow((m + 0.055) / 1.055, 2.4) : m / 12.92
        return CGFloat(signOf: v, magnitudeOf: out)
    }

    /// The inverse sRGB transfer function, from linear light to gamma-encoded.
    static func gammaEncoded(_ v: CGFloat) -> CGFloat {
        let m = abs(v)
        let out = m > 0.003_130_8 ? 1.055 * pow(m, 1 / 2.4) - 0.055 : m * 12.92
        return CGFloat(signOf: v, magnitudeOf: out)
    }

    /// A hue between `from` and `to` along the shorter arc.
    static func lerpHue(_ from: CGFloat, _ to: CGFloat, _ t: CGFloat) -> CGFloat {
        let delta = ((to - from).truncatingRemainder(dividingBy: 360) + 540).truncatingRemainder(dividingBy: 360) - 180
        return (from + delta * t + 360).truncatingRemainder(dividingBy: 360)
    }

    private static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    // MARK: - sRGB

    /// Gamma-encoded sRGB, nominally 0...1 per channel.
    struct RGB: Equatable {
        var red: CGFloat
        var green: CGFloat
        var blue: CGFloat
        var alpha: CGFloat

        func withAlpha(_ alpha: CGFloat) -> RGB {
            RGB(red: red, green: green, blue: blue, alpha: alpha)
        }

        func color() -> UIColor {
            UIColor(red: red, green: green, blue: blue, alpha: alpha)
        }

        /// Every channel clipped to 0...1. LCH paths can leave the gamut for saturated colours.
        func clamped() -> RGB {
            func clip(_ v: CGFloat) -> CGFloat { min(max(v, 0), 1) }
            return RGB(red: clip(red), green: clip(green), blue: clip(blue), alpha: clip(alpha))
        }

        func lerp(_ other: RGB, _ t: CGFloat) -> RGB {
            RGB(
                red: ColorMath.lerp(red, other.red, t),
                green: ColorMath.lerp(green, other.green, t),
                blue: ColorMath.lerp(blue, other.blue, t),
                alpha: ColorMath.lerp(alpha, other.alpha, t)
            )
        }

        var xyz: XYZ {
            let r = linearized(red), g = linearized(green), b = linearized(blue)
            return XYZ(
                x: r * 0.412_456_4 + g * 0.357_576_1 + b * 0.180_437_5,
                y: r * 0.212_672_9 + g * 0.715_152_2 + b * 0.072_175_0,
                z: r * 0.019_333_9 + g * 0.119_192_0 + b * 0.950_304_1
            )
        }

        var lch: LCH { xyz.lab.lch(alpha: alpha) }

        var hsb: HSB {
            let high = max(red, green, blue), low = min(red, green, blue)
            let range = high - low
            var hue: CGFloat = 0
            if range > 0 {
                if high == red {
                    hue = (green - blue) / range
                } else if high == green {
                    hue = 2 + (blue - red) / range
                } else {
                    hue = 4 + (red - green) / range
                }
                hue *= 60
                if hue < 0 { hue += 360 }
            }
            return HSB(hue: hue, saturation: high > 0 ? range / high : 0, brightness: high, alpha: alpha)
        }
    }

    // MARK: - HSB

    /// Hue in degrees, saturation and brightness 0...1.
    struct HSB: Equatable {
        var hue: CGFloat
        var saturation: CGFloat
        var brightness: CGFloat
        var alpha: CGFloat

        func lerp(_ other: HSB, _ t: CGFloat) -> HSB {
            HSB(
                hue: lerpHue(hue, other.hue, t),
                saturation: ColorMath.lerp(saturation, other.saturation, t),
                brightness: ColorMath.lerp(brightness, other.brightness, t),
                alpha: ColorMath.lerp(alpha, other.alpha, t)
            )
        }

        var rgb: RGB {
            let h = (hue.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 60
            let sector = floor(h), f = h - sector
            let v = brightness, s = saturation
            let p = v * (1 - s), q = v * (1 - s * f), u = v * (1 - s * (1 - f))
            let (r, g, b): (CGFloat, CGFloat, CGFloat)
            switch Int(sector) {
            case 0: (r, g, b) = (v, u, p)
            case 1: (r, g, b) = (q, v, p)
            case 2: (r, g, b) = (p, v, u)
            case 3: (r, g, b) = (p, q, v)
            case 4: (r, g, b) = (u, p, v)
            default: (r, g, b) = (v, p, q)
            }
            return RGB(red: r, green: g, blue: b, alpha: alpha)
        }
    }

    // MARK: - CIE XYZ

    /// Linear-light CIE XYZ under D65, Y of white = 1.
    struct XYZ {
        var x: CGFloat
        var y: CGFloat
        var z: CGFloat

        func rgb(alpha: CGFloat) -> RGB {
            RGB(
                red: gammaEncoded(x * 3.240_454_2 + y * -1.537_138_5 + z * -0.498_531_4),
                green: gammaEncoded(x * -0.969_266_0 + y * 1.876_010_8 + z * 0.041_556_0),
                blue: gammaEncoded(x * 0.055_643_4 + y * -0.204_025_9 + z * 1.057_225_2),
                alpha: alpha
            )
        }

        var lab: Lab {
            func f(_ t: CGFloat) -> CGFloat { t > labEpsilon ? cbrt(t) : (labKappa * t + 16) / 116 }
            let fx = f(x / whitePoint.x), fy = f(y / whitePoint.y), fz = f(z / whitePoint.z)
            return Lab(lightness: 116 * fy - 16, a: 500 * (fx - fy), b: 200 * (fy - fz))
        }
    }

    // MARK: - CIE Lab

    /// Lightness 0...100; a and b roughly -128...128.
    struct Lab {
        var lightness: CGFloat
        var a: CGFloat
        var b: CGFloat

        var xyz: XYZ {
            func fInverse(_ t: CGFloat) -> CGFloat {
                let cube = t * t * t
                return cube > labEpsilon ? cube : (116 * t - 16) / labKappa
            }
            let fy = (lightness + 16) / 116
            return XYZ(
                x: fInverse(fy + a / 500) * whitePoint.x,
                y: fInverse(fy) * whitePoint.y,
                z: fInverse(fy - b / 200) * whitePoint.z
            )
        }

        func lch(alpha: CGFloat) -> LCH {
            let hue = atan2(b, a).radiansToDegrees
            return LCH(lightness: lightness, chroma: sqrt(a * a + b * b), hue: hue < 0 ? hue + 360 : hue, alpha: alpha)
        }
    }

    // MARK: - CIE LCh

    /// Lightness 0...100, chroma from 0 (about 134 at the edge of sRGB), hue in degrees.
    struct LCH: Equatable {
        /// Below this chroma a hue counts for less and less: the system greys sit
        /// around 2 to 5, a beige around 13, muted teals and cyans from about 35.
        static let neutralChroma: CGFloat = 20

        var lightness: CGFloat
        var chroma: CGFloat
        var hue: CGFloat
        var alpha: CGFloat

        var lab: Lab {
            let angle = hue.degreesToRadians
            return Lab(lightness: lightness, a: cos(angle) * chroma, b: sin(angle) * chroma)
        }

        /// Unclamped: saturated colours can land outside sRGB. See ``RGB/clamped()``.
        var rgb: RGB { lab.xyz.rgb(alpha: alpha) }

        /// Hue takes the shorter arc, weighted by how much each end has a hue at
        /// all: from a grey or near-grey it heads straight for the other end's
        /// instead of sweeping round the wheel. Between two colours at or above
        /// ``neutralChroma`` it is a plain lerp. The weight is squared so a
        /// near-grey's hue fades about as fast as its share of the chroma.
        func lerp(_ other: LCH, _ t: CGFloat) -> LCH {
            func weight(_ c: CGFloat) -> CGFloat { pow(min(c / LCH.neutralChroma, 1), 2) }
            let w0 = weight(chroma), w1 = weight(other.chroma)
            let total = (1 - t) * w0 + t * w1
            let hueProgress = total > 0 ? t * w1 / total : t
            return LCH(
                lightness: ColorMath.lerp(lightness, other.lightness, t),
                chroma: ColorMath.lerp(chroma, other.chroma, t),
                hue: lerpHue(hue, other.hue, hueProgress),
                alpha: ColorMath.lerp(alpha, other.alpha, t)
            )
        }
    }
}
#endif
