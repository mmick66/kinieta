/*
 * UIColor+Components.swift
 
 * Created by Michael Michailidis on 16/10/2017.
 * http://blog.karmadust.com/
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

/* Thanks to Gregor Aisch from https://github.com/gka/chroma.js  */

import UIKit

extension UIColor {
    
    public struct Components: CGFractionable, Equatable, CustomStringConvertible {
        
        var c1: CGFloat, c2: CGFloat, c3: CGFloat, alpha: CGFloat
        public enum Space: String {
            case RGB = "RGB"
            case HSB = "HSB"
            case HCL = "HCL"
        }
        let space: Space
        init(_ c1: CGFloat, _ c2: CGFloat, _ c3: CGFloat, _ alpha: CGFloat, space: Components.Space) {
            self.c1     = c1
            self.c2     = c2
            self.c3     = c3
            self.alpha  = alpha
            self.space  = space
        }
        
        public static func ==(lhs:Components, rhs:Components) -> Bool {
            guard lhs.space == rhs.space else { return false }
            return (lhs.c1 == rhs.c1) && (lhs.c2 == rhs.c2) && (lhs.c3 == rhs.c3) && (lhs.alpha == rhs.alpha)
        }
        
        public var description: String {
            return "(c1:\(c1), c2:\(c2), c3:\(c3), alpha:\(alpha), space:\(space.rawValue))"
        }
        
        static func *(lhs:Components, rhs:CGFloat) -> Components {
            return UIColor.Components(lhs.c1 * rhs, lhs.c2 * rhs, lhs.c3 * rhs, lhs.alpha * rhs, space: lhs.space)
        }
        static func /(lhs:Components, rhs:CGFloat) -> UIColor.Components {
            return UIColor.Components(lhs.c1 / rhs, lhs.c2 / rhs, lhs.c3 / rhs, lhs.alpha / rhs, space: lhs.space)
        }
        
        static func *(lhs:CGFloat, rhs:Components) -> Components {
            return rhs * lhs
        }
        static func -(lhs:Components, rhs: Components) -> Components {
            guard lhs.space == rhs.space else { fatalError("Cannot subtract two colors from different spaces") }
            return Components(
                lhs.c1 - rhs.c1,
                lhs.c2 - rhs.c2,
                lhs.c3 - rhs.c3,
                lhs.alpha - rhs.alpha,
                space: lhs.space
            )
        }
        
        static func +(lhs:Components, rhs:Components) -> Components {
            guard lhs.space == rhs.space else { fatalError("Cannot multiply two colors from different spaces") }
            return Components(
                lhs.c1 + rhs.c1,
                lhs.c2 + rhs.c2,
                lhs.c3 + rhs.c3,
                lhs.alpha + rhs.alpha,
                space: lhs.space
            )
        }
    }
    
    func components(as space: Components.Space) -> Components {
        
        switch space {
        case .RGB:
            let (r, g, b, a) = self.rgba
            return Components(r, g, b, a, space: .RGB)
        case .HSB:
            let (h, s, b, a) = self.hsba
            return Components(h, s, b, a, space: .HSB)
        case .HCL:
            let (h, l, c, a) = self.hlca
            return Components(h, l, c, a, space: .HCL)
        }
        
    }

    convenience init(components comps: Components) {
        switch comps.space {
        case .RGB:
            self.init(red: comps.c1, green: comps.c2, blue: comps.c3, alpha: comps.alpha)
        case .HSB:
            self.init(hue: comps.c1, saturation: comps.c2, brightness: comps.c3, alpha: comps.alpha)
        case .HCL:
            self.init(hue: comps.c1, luminance: comps.c2, chroma: comps.c3, alpha: comps.alpha)
        }
        
    }

    
    /// Samples the perceptual (LCH) path from this colour to `toColor` at
    /// `stops + 1` evenly spaced points, from this colour to `toColor` inclusive.
    ///
    /// Hue is interpolated along the shorter arc, an achromatic endpoint adopts
    /// the other endpoint's hue, and each sample is clamped to the sRGB gamut.
    func spectrumComponentsHLC5(to toColor: UIColor, stops: Int = 5) -> [UIColor] {
        var from = self.rgbColor().toLCH()
        var to   = toColor.rgbColor().toLCH()
        let achromatic: CGFloat = 1e-3
        if from.c < achromatic { from = LCHColor(l: from.l, c: from.c, h: to.h, alpha: from.alpha) }
        if to.c   < achromatic { to   = LCHColor(l: to.l,   c: to.c,   h: from.h, alpha: to.alpha) }
        return (0 ... stops).map { i in
            from.lerp(to, t: CGFloat(i) / CGFloat(stops)).toRGB().clamped().color()
        }
    }
    
}


