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

typealias LabConstantsType = (Kn: CGFloat, Xn: CGFloat, Yn: CGFloat, Zn: CGFloat, t0: CGFloat, t1: CGFloat, t2: CGFloat, t3: CGFloat)
let LAB_CONSTANTS: LabConstantsType = (
    Kn: 18.0,
    Xn: 0.950470,
    Yn: 1.0,
    Zn: 1.088830,
    t0: 0.137931034,
    t1: 0.206896552,
    t2: 0.12841855,
    t3: 0.008856452
)

extension UIColor {
    
    typealias ComponentData = (c1: CGFloat, c2: CGFloat, c3: CGFloat, a: CGFloat)
    struct Components: CGFractionable {
        
        var c1: CGFloat, c2: CGFloat, c3: CGFloat, alpha: CGFloat
        enum Space {
            case RGB
            case HSB
            case LAB
        }
        let space: Space
        init(_ data: ComponentData, space: Components.Space) {
            self.init(data.c1, data.c2, data.c3, alpha: data.a, space: space)
        }
        init(_ c1: CGFloat, _ c2: CGFloat, _ c3: CGFloat, alpha: CGFloat, space: Components.Space) {
            self.c1     = c1
            self.c2     = c2
            self.c3     = c3
            self.alpha  = alpha
            self.space  = space
        }
    }
    
    func components(as space: Components.Space = Kinieta.ColorInterpolation) -> Components {
        var data: ComponentData
        switch space {
        case .RGB:  data = self.rgba()
        case .HSB:  data = self.hsba()
        case .LAB:  data = self.laba()
        }
        return Components(data, space: space)
    }
    
    
    // Component Getters
    func rgba() -> ComponentData {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (c1: r, c2: g, c3: b, a: a)
    }
    func hsba() -> ComponentData {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        self.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (c1: h, c2: s, c3: b, a: a)
    }
    
    
    func laba() -> ComponentData {
        let rgb2xyz = { (c:CGFloat) -> CGFloat in
            let cn = c / 255.0
            if cn <= 0.04045 { return cn / 12.92 }
            else { return pow((cn + 0.055) / 1.055, 2.4) }
        }
        let xyz2lab = { (c:CGFloat) -> CGFloat in
            if c > LAB_CONSTANTS.t3 { return pow(c, 1 / 3) }
            else { return c / LAB_CONSTANTS.t2 + LAB_CONSTANTS.t0 }
        }
        let rgba = self.rgba()
        let red     = rgb2xyz(rgba.c1)
        let green   = rgb2xyz(rgba.c2)
        let blue    = rgb2xyz(rgba.c3)
        let l       = xyz2lab(0.4124564 * red + 0.3575761 * green + 0.1804375 * blue) / LAB_CONSTANTS.Xn
        let a       = xyz2lab(0.2126729 * red + 0.7151522 * green + 0.0721750 * blue) / LAB_CONSTANTS.Yn
        let b       = xyz2lab(0.0193339 * red + 0.1191920 * green + 0.9503041 * blue) / LAB_CONSTANTS.Zn
        return (c1: l, c2: a, c3: b, a: rgba.a)
    }
    convenience init(components comps: Components) {
        switch comps.space {
        case .RGB: self.init(red: comps.c1, green: comps.c2, blue: comps.c3, alpha: comps.alpha)
        case .HSB: self.init(hue: comps.c1, saturation: comps.c2, brightness: comps.c3, alpha: comps.alpha)
        case .LAB: self.init(lightness: comps.c1, a: comps.c2, b: comps.c3, alpha: comps.alpha)
        }
        
    }
    
    convenience init(lightness: CGFloat, a: CGFloat, b: CGFloat, alpha: CGFloat) {
        
        let lab2xyz = { (t:CGFloat) -> CGFloat in
            if t > LAB_CONSTANTS.t1 { return t * t * t }
            else { return LAB_CONSTANTS.t2 * (t - LAB_CONSTANTS.t0) }
        }
        let xyz2rgb = { (r:CGFloat) -> CGFloat in
            return 255 * (r <= 0.00304 ? 12.92 * r : 1.055 * pow(r, 1 / 2.4) - 0.055)
        }
        var y = (lightness + 16.0) / 116.0
        var x = y + a / 500.0
        var z = y - b / 200.0
        
        y = LAB_CONSTANTS.Yn * lab2xyz(y)
        x = LAB_CONSTANTS.Xn * lab2xyz(x)
        z = LAB_CONSTANTS.Zn * lab2xyz(z)
        
        let r = xyz2rgb(3.2404542 * x - 1.5371385 * y - 0.4985314 * z)
        let g = xyz2rgb(-0.9692660 * x + 1.8760108 * y + 0.0415560 * z)
        let b = xyz2rgb(0.0556434 * x - 0.2040259 * y + 1.0572252 * z)
        
        self.init(red: r, green: g, blue: b, alpha: alpha)
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
