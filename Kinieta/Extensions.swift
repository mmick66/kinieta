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
    struct Components: CGFractionable {
        var r: CGFloat
        var g: CGFloat
        var b: CGFloat
        var a: CGFloat
        static func *(lhs:CGFloat, rhs:UIColor.Components) -> Components {
            return Components(
                r: lhs * rhs.r,
                g: lhs * rhs.g,
                b: lhs * rhs.b,
                a: lhs * rhs.a
            )
        }
        static func *(lhs:UIColor.Components, rhs:CGFloat) -> Components {
            return Components(
                r: lhs.r * rhs,
                g: lhs.g * rhs,
                b: lhs.b * rhs,
                a: lhs.a * rhs
            )
        }
        static func +(lhs:UIColor.Components, rhs:UIColor.Components) -> Components {
            return Components(
                r: lhs.r + rhs.r,
                g: lhs.g + rhs.g,
                b: lhs.b + rhs.b,
                a: lhs.a + rhs.a
            )
        }
    }
    var components: Components? {
        guard let comps = self.cgColor.components else {
            return nil
        }
        switch comps.count {
        case 2:
            return Components(r: comps[0], g: comps[0], b: comps[0], a: comps[1])
        case 3:
            return Components(r: comps[0], g: comps[1], b: comps[2], a: 1.0)
        default:
            return Components(r: comps[0], g: comps[1], b: comps[2], a: comps[3])
        }
    }
    convenience init(components cmps: Components) {
        self.init(red: cmps.r, green: cmps.g, blue: cmps.b, alpha: cmps.a)
    }
    
}
