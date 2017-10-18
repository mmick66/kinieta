/*
 * Extensions.swift
 
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

import UIKit

extension FloatingPoint {
    var degreesToRadians: Self { return self * .pi / 180 }
    var radiansToDegrees: Self { return self * 180 / .pi }
}

protocol CGFractionable {
    static func *(lhs: CGFloat, rhs: Self) -> Self
    static func *(lhs: Self, rhs: CGFloat) -> Self
    static func +(lhs: Self, rhs: Self) -> Self
}

extension CGRect: CGFractionable {
    static func *(lhs:CGFloat, rhs:CGRect) -> CGRect {
        return CGRect(
            x: lhs * rhs.origin.x,
            y: lhs * rhs.origin.y,
            width: lhs * rhs.size.width,
            height: lhs * rhs.size.height
        )
    }
    static func *(lhs:CGRect, rhs:CGFloat) -> CGRect {
        return CGRect(
            x: lhs.origin.x * rhs,
            y: lhs.origin.y * rhs,
            width: lhs.size.width * rhs,
            height: lhs.size.height * rhs
        )
    }
    static func +(lhs:CGRect, rhs:CGRect) -> CGRect {
        return CGRect(
            x: lhs.origin.x + rhs.origin.x,
            y: lhs.origin.y + rhs.origin.y,
            width: lhs.size.width + rhs.size.width,
            height: lhs.size.height + rhs.size.height
        )
    }
}


extension CGFloat: CGFractionable {
    static func parse(_ any: Any?) -> CGFloat? {
        guard let a = any else { return nil }
        switch a {
        case let x as CGFloat:  return CGFloat(x)
        case let x as Float:    return CGFloat(x)
        case let x as Int:      return CGFloat(x)
        case let x as Double:   return CGFloat(x)
        case let x as UInt8:    return CGFloat(x)
        case let x as Int8:     return CGFloat(x)
        case let x as UInt16:   return CGFloat(x)
        case let x as Int16:    return CGFloat(x)
        case let x as UInt32:   return CGFloat(x)
        case let x as Int32:    return CGFloat(x)
        case let x as UInt64:   return CGFloat(x)
        case let x as Int64:    return CGFloat(x)
        case let x as UInt:     return CGFloat(x)
        default:                return nil
        }
    }
}

extension Dictionary where Key == String, Value == Any {
    mutating func pop(_ key: String) -> Any? {
        return self.removeValue(forKey: key)
    }
    func intersection(_ keys: [String]) -> Bool {
        for (k,_) in self {
            if keys.contains(k) {
                return true
            }
        }
        return false
    }
}

extension UIColor {
    typealias RGBA = (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)
    typealias HSBA = (h: CGFloat, s:CGFloat, b:CGFloat, a:CGFloat)
    struct Components: CGFractionable {
        
        var c1: CGFloat, c2: CGFloat, c3: CGFloat, a: CGFloat
        enum Space {
            case RGB
            case HSB
        }
        let space: Space
        init(c1: CGFloat, c2: CGFloat, c3: CGFloat, a: CGFloat, space: Components.Space) {
            self.c1 = c1
            self.c2 = c2
            self.c3 = c3
            self.a = a
            self.space = space
        }
        init(rgba: RGBA) {
            self.c1 = rgba.r
            self.c2 = rgba.g
            self.c3 = rgba.b
            self.a = rgba.a
            self.space = Space.RGB
        }
        init(hsba: HSBA) {
            self.c1 = hsba.h
            self.c2 = hsba.s
            self.c3 = hsba.b
            self.a = hsba.a
            self.space = Space.HSB
        }
        static func *(lhs:UIColor.Components, rhs:CGFloat) -> Components {
            return Components(c1: lhs.c1 * rhs, c2: lhs.c2 * rhs, c3: lhs.c3 * rhs, a: lhs.a * rhs, space: lhs.space)
        }
        static func *(lhs:CGFloat, rhs:UIColor.Components) -> Components {
            return rhs * lhs
        }
        
        static func +(lhs:UIColor.Components, rhs:UIColor.Components) -> Components {
            return Components(c1: lhs.c1 + rhs.c1, c2: lhs.c2 + rhs.c2, c3: lhs.c3 + rhs.c3, a: lhs.a + rhs.a, space: lhs.space)
        }
    }
    
    func components(for space: Components.Space) -> Components {
        switch space {
        case .RGB:  return Components(rgba: self.rgba)
        case .HSB:  return Components(hsba: self.hsba)
        }
    }
    
    
    // Component Getters
    var rgba: RGBA {
        var _r: CGFloat = 0, _g: CGFloat = 0, _b: CGFloat = 0, _a: CGFloat = 0
        self.getRed(&_r, green: &_g, blue: &_b, alpha: &_a)
        return (r: _r, g: _g, b: _b, a: _a)
    }
    var hsba: HSBA {
        var _h: CGFloat = 0, _s: CGFloat = 0, _b: CGFloat = 0, _a: CGFloat = 0
        self.getHue(&_h, saturation: &_s, brightness: &_b, alpha: &_a)
        return (h: _h, s: _s, b: _b, a: _a)
    }
    convenience init(components comps: Components) {
        switch comps.space {
        case .RGB: self.init(red: comps.c1, green: comps.c2, blue: comps.c3, alpha: comps.a)
        case .HSB: self.init(hue: comps.c1, saturation: comps.c2, brightness: comps.c3, alpha: comps.a)
        }
        
    }
    
}

extension Dictionary {
    func toString() -> String {
        return self.map({ return "\($0):\($1)" }).joined(separator: " ")
    }
}
