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
        
        init(rgba: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)) {
            self.init(rgba.red, rgba.green, rgba.blue, alpha: rgba.alpha, space: .RGB)
        }
        init(hsba: (hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat)) {
            self.init(hsba.hue, hsba.saturation, hsba.brightness, alpha: hsba.alpha, space: .HSB)
        }
        init(hlca: (hue: CGFloat, luminance: CGFloat, chroma: CGFloat, alpha: CGFloat)) {
            self.init(hlca.hue, hlca.luminance, hlca.chroma, alpha: hlca.alpha, space: .HSB)
        }
        
        init(_ c1: CGFloat, _ c2: CGFloat, _ c3: CGFloat, alpha: CGFloat, space: Components.Space) {
            self.c1     = c1
            self.c2     = c2
            self.c3     = c3
            self.alpha  = alpha
            self.space  = space
        }
        
        static func ==(lhs:Components, rhs:Components) -> Bool {
            return (lhs.c1 == rhs.c1) && (lhs.c2 == rhs.c2) && (lhs.c3 == rhs.c3) && (lhs.alpha == rhs.alpha) && (lhs.space == rhs.space)
        }
        
        var description: String {
            return "(c1:\(c1), c2:\(c2), c3:\(c3), alpha:\(alpha), space:\(space.rawValue))"
        }
    }
    
    func components(as space: Components.Space = Kinieta.ColorInterpolation) -> Components {
        
        switch space {
        case .RGB: return Components(rgba: self.rgba)
        case .HSB: return Components(hsba: self.hsba)
        case .HLC: return Components(hlca: self.hlca)
        }
        
    }


    convenience init(components comps: Components) {
        switch comps.space {
        case .RGB: self.init(red: comps.c1, green: comps.c2, blue: comps.c3, alpha: comps.alpha)
        case .HSB: self.init(hue: comps.c1, saturation: comps.c2, brightness: comps.c3, alpha: comps.alpha)
        case .HLC: self.init(hue: comps.c1, luminance: comps.c2, chroma: comps.c3, alpha: comps.alpha)
        }
        
    }

    
}

infix operator </>

func </>(lhs: UIColor.Components, rhs: UIColor.Components) -> UIColor.Components {
    guard lhs.space == rhs.space else { fatalError("Cannot average two colors with different space") }
    let c1 = (lhs.c1 + rhs.c1) / 2.0
    let c2 = (lhs.c1 + rhs.c1) / 2.0
    let c3 = (lhs.c1 + rhs.c1) / 2.0
    let ca = (lhs.alpha + rhs.alpha) / 2.0
    return UIColor.Components(c1, c2, c3, alpha: ca, space: lhs.space)
}

func *(lhs:UIColor.Components, rhs:CGFloat) -> UIColor.Components {
    return UIColor.Components(lhs.c1 * rhs, lhs.c2 * rhs, lhs.c3 * rhs, alpha: lhs.alpha * rhs, space: lhs.space)
}
func *(lhs:CGFloat, rhs:UIColor.Components) -> UIColor.Components {
    return rhs * lhs
}

func +(lhs:UIColor.Components, rhs:UIColor.Components) -> UIColor.Components {
    return UIColor.Components(lhs.c1 + rhs.c1, lhs.c2 + rhs.c2, lhs.c3 + rhs.c3, alpha: lhs.alpha + rhs.alpha, space: lhs.space)
}


func </>(lhs: UIColor, rhs: UIColor) -> UIColor {
    let cs = lhs.components() </> rhs.components()
    return UIColor(components: cs)
}
