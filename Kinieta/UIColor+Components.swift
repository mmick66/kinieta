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
    
    struct Components: CGFractionable, Equatable, CustomStringConvertible {
        
        var c1: CGFloat, c2: CGFloat, c3: CGFloat, alpha: CGFloat
        enum Space: String {
            case RGB = "RGB"
            case HSB = "HSB"
            case HLC = "HLC"
        }
        let space: Space
        init(_ c1: CGFloat, _ c2: CGFloat, _ c3: CGFloat, _ alpha: CGFloat, space: Components.Space) {
            self.c1     = c1
            self.c2     = c2
            self.c3     = c3
            self.alpha  = alpha
            self.space  = space
        }
        
        static func ==(lhs:Components, rhs:Components) -> Bool {
            guard lhs.space == rhs.space else { return false }
            return (lhs.c1 == rhs.c1) && (lhs.c2 == rhs.c2) && (lhs.c3 == rhs.c3) && (lhs.alpha == rhs.alpha)
        }
        
        var description: String {
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
        case .HLC:
            let (h, l, c, a) = self.hlca
            return Components(h, l, c, a, space: .HLC)
        }
        
    }

    convenience init(components comps: Components) {
        switch comps.space {
        case .RGB:
            self.init(red: comps.c1, green: comps.c2, blue: comps.c3, alpha: comps.alpha)
        case .HSB:
            self.init(hue: comps.c1, saturation: comps.c2, brightness: comps.c3, alpha: comps.alpha)
        case .HLC:
            self.init(hue: comps.c1, luminance: comps.c2, chroma: comps.c3, alpha: comps.alpha)
        }
        
    }

    
    func spectrumComponentsHLC5(to toColor: UIColor) -> [UIColor] {
        
        var spectrum = [UIColor]()
        
        let fcomps  = self.components(as: .HLC)
        let tcomps  = toColor.components(as: .HLC)
        
        for i in 0 ... 5 {
            let factor  = CGFloat(i) / 5.0
            let comps   = (1.0 - factor) * fcomps + factor * tcomps
            let color   = UIColor(components: comps)
            spectrum.append(color)
        }
        
        return spectrum
    }
    
}


