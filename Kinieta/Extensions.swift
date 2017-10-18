//
//  Extensions.swift
//  Kinieta
//
//  Created by Michael Michailidis on 16/10/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

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
        
        var x: CGFloat, y: CGFloat, z: CGFloat, a: CGFloat
        enum Space {
            case RGB
            case HSB
        }
        let space: Space
        init(x: CGFloat, y: CGFloat, z: CGFloat, a: CGFloat, space: Components.Space) {
            self.x = x
            self.y = y
            self.z = z
            self.a = a
            self.space = space
        }
        init(rgba: RGBA) {
            self.x = rgba.r
            self.y = rgba.g
            self.z = rgba.b
            self.a = rgba.a
            self.space = Space.RGB
        }
        init(hsba: HSBA) {
            self.x = hsba.h
            self.y = hsba.s
            self.z = hsba.b
            self.a = hsba.a
            self.space = Space.HSB
        }
        static func *(lhs:UIColor.Components, rhs:CGFloat) -> Components {
            return Components(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs, a: lhs.a * rhs, space: lhs.space)
        }
        static func *(lhs:CGFloat, rhs:UIColor.Components) -> Components {
            return rhs * lhs
        }
        
        static func +(lhs:UIColor.Components, rhs:UIColor.Components) -> Components {
            return Components(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z, a: lhs.a + rhs.a, space: lhs.space)
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
        case .RGB: self.init(red: comps.x, green: comps.y, blue: comps.z, alpha: comps.a)
        case .HSB: self.init(hue: comps.x, saturation: comps.y, brightness: comps.z, alpha: comps.a)
        }
        
    }
    
}

extension Dictionary {
    func toString() -> String {
        return self.map({ return "\($0):\($1)" }).joined(separator: " ")
    }
}
