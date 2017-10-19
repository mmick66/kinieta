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


extension Dictionary {
    func toString() -> String {
        return self.map({ return "\($0):\($1)" }).joined(separator: " ")
    }
}
