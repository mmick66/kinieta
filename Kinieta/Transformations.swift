//
//  Interpolations.swift
//  Kinieta
//
//  Created by Michael Michailidis on 06/09/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

func createFloatInterpolation(from start:CGFloat, to end:CGFloat, block: @escaping (CGFloat) -> Void) -> TransformationBlock {
    
    return { factor in
        let cgFloatFactor = CGFloat(factor)
        let iFloat = (1.0 - cgFloatFactor) * start + cgFloatFactor * end
        block(iFloat)
    }
}

func createColorInterpolation(from start:UIColor, to end:UIColor, block: @escaping (UIColor) -> Void) -> TransformationBlock {
    
    let components = { (color: UIColor) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? in
        guard let components = color.cgColor.components else { return nil }
        if components.count == 2 {
            return (r: components[0], g: components[0], b: components[0], a: components[1])
        } else {
            return (r: components[0], g: components[1], b: components[2], a: components[3])
        }
    }
    
    guard
        let startComponents = components(start),
        let endComponents   = components(end) else { return { _ in } }
    
    return { factor in
        
        let cgFloatFactor = CGFloat(factor)
        
        let r = (1.0 - cgFloatFactor) * startComponents.r + cgFloatFactor * endComponents.r
        let g = (1.0 - cgFloatFactor) * startComponents.g + cgFloatFactor * endComponents.g
        let b = (1.0 - cgFloatFactor) * startComponents.b + cgFloatFactor * endComponents.b
        let a = (1.0 - cgFloatFactor) * startComponents.a + cgFloatFactor * endComponents.a
        
        let iColor = UIColor(red: r, green: g, blue: b, alpha: a)
        
        block(iColor)
    }
}

typealias TransformationBlock = (Double) -> Void
func createTransormation(in view: UIView, for property:String, with value:Any) -> TransformationBlock {
    
    let cgFloatValue: CGFloat = cgfloat(value) ?? 1.0
    
    switch property {
        
    case "x":
        return createFloatInterpolation(from: view.center.x, to: cgFloatValue) { nValue in
            view.center = CGPoint(x: nValue, y: view.center.y)
        }
        
    case "y":
        return createFloatInterpolation(from: view.center.y, to: cgFloatValue) { nValue in
            view.center = CGPoint(x: view.center.x, y: nValue)
        }
        
    case "w", "width":
        return createFloatInterpolation(from: view.frame.size.width, to: cgFloatValue) { nValue in
            var oFrame = view.frame
            oFrame.size.width = nValue
            view.frame = oFrame
        }
        
    case "h", "height":
        return createFloatInterpolation(from: view.frame.size.height, to: cgFloatValue) { nValue in
            var oFrame = view.frame
            oFrame.size.height = nValue
            view.frame = oFrame
        }
        
    case "r", "rotation":
        return createFloatInterpolation(from: view.rotation, to: cgFloatValue) { nValue in
            view.rotation = nValue
        }
        
    case "a", "alpha":
        return createFloatInterpolation(from: view.alpha, to: cgFloatValue) { nValue in
            view.alpha = nValue
        }
        
    case "bg", "background":
        let ibg = view.backgroundColor != nil ? view.backgroundColor! : UIColor.clear
        return createColorInterpolation(from: ibg , to: value as! UIColor) { nColor in
            view.backgroundColor = nColor
        }
        
    case "brc", "borderColor":
        let ibrc = view.layer.borderColor != nil ? UIColor(cgColor: view.layer.borderColor!) : UIColor.clear
        return createColorInterpolation(from: ibrc, to: value as! UIColor) { nColor in
            view.layer.borderColor = nColor.cgColor
        }
        
    case "brw", "borderWidth":
        return createFloatInterpolation(from: view.layer.borderWidth, to: cgFloatValue) { nValue in
            view.layer.borderWidth = nValue
        }
        
    case "crd", "cornerRadius":
        return createFloatInterpolation(from: view.layer.borderWidth, to: cgFloatValue) { nValue in
            view.layer.borderWidth = nValue
        }
        
    default:
        return { _ in }
    }
    
}

func radians(_ degrees: CGFloat) -> CGFloat {
    return degrees * (CGFloat.pi / 180.0)
}

func clamp<T: Comparable>(value: T, lower: T, upper: T) -> T {
    return min(max(value, lower), upper)
}

func cgfloat(_ any: Any) -> CGFloat? {
    switch any {
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

