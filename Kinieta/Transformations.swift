//
//  Transformations.swift
//  Kinieta
//
//  Created by Michael Michailidis on 31/08/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

open class Transformation {
    
    typealias TransformationBlock = (Double) -> Void
    
    private let view:UIView
    
    private let timeframe:Range<TimeInterval>
    
    private var transformations:[TransformationBlock] = []
    
    init(_ view:UIView, for properties: [String:Any], from: Double, to: Double) {
        
        self.view = view
        self.timeframe = from..<to
        
        for (key, value) in properties {
            let transformation = createTransormation(of: key, for: value)
            transformations.append(transformation)
        }
    }
    
    @discardableResult func execute(for timestamp: Double) -> Bool {
        
        guard timeframe.contains(timestamp) else {
            return true
        }
        
        let factor = (timestamp - timeframe.lowerBound) / (timeframe.upperBound - timeframe.lowerBound)
        
        for transformation in transformations {
            transformation(factor)
        }
        
        return false
    }
    
    private func createTransormation(of property:String, for value:Any) -> TransformationBlock {
        
        let cgFloatValue: CGFloat = (value as? CGFloat) ?? 1.0
    
        switch property {
            
        case "x":
            return createFloatInterpolation(from: self.view.center.x, to: cgFloatValue) { nValue in
                self.view.center = CGPoint(x: nValue, y: self.view.center.y)
            }
            
        case "y":
            return createFloatInterpolation(from: self.view.center.x, to: cgFloatValue) { nValue in
                self.view.center = CGPoint(x: self.view.center.x, y: nValue)
            }
            
        case "w", "width":
            return createFloatInterpolation(from: self.view.frame.size.width, to: cgFloatValue) { nValue in
                var oFrame = self.view.frame
                oFrame.size.width = nValue
                self.view.frame = oFrame
            }
            
        case "h", "height":
            return createFloatInterpolation(from: self.view.frame.size.height, to: cgFloatValue) { nValue in
                var oFrame = self.view.frame
                oFrame.size.height = nValue
                self.view.frame = oFrame
            }
            
        case "r", "rotation":
            return createFloatInterpolation(from: self.view.rotation, to: cgFloatValue) { nValue in
                self.view.rotation = nValue
            }
            
        case "a", "alpha":
            return createFloatInterpolation(from: self.view.alpha, to: cgFloatValue) { nValue in
                self.view.alpha = nValue
            }
            
        case "bg", "background":
            return createColorInterpolation(from: self.view.backgroundColor ?? UIColor.white, to: value as! UIColor) { nColor in
                self.view.backgroundColor = nColor
            }
            
        case "brc", "borderColor":
            return createColorInterpolation(from: self.view.backgroundColor ?? UIColor.white, to: value as! UIColor) { nColor in
                self.view.layer.borderColor = nColor.cgColor
            }
            
        case "brw", "borderWidth":
            return createFloatInterpolation(from: self.view.layer.borderWidth, to: cgFloatValue) { nValue in
                self.view.layer.borderWidth = nValue
            }
            
        default:
            return { _ in }
        }

    }
    
    private func createFloatInterpolation(from start:CGFloat, to end:CGFloat, block: @escaping (CGFloat) -> Void) -> TransformationBlock {
        
        return { factor in
            let cgFloatFactor = CGFloat(factor)
            let iFloat = (1.0 - cgFloatFactor) * start + cgFloatFactor * end
            block(iFloat)
            
        }
    }
    
    private func createColorInterpolation(from start:UIColor, to end:UIColor, block: @escaping (UIColor) -> Void) -> TransformationBlock {
        
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
            
            let r = (1 - cgFloatFactor) * startComponents.r + cgFloatFactor * endComponents.r
            let g = (1 - cgFloatFactor) * startComponents.g + cgFloatFactor * endComponents.g
            let b = (1 - cgFloatFactor) * startComponents.b + cgFloatFactor * endComponents.b
            let a = (1 - cgFloatFactor) * startComponents.a + cgFloatFactor * endComponents.a
            
            let iColor = UIColor(red: r, green: g, blue: b, alpha: a)
            
            block(iColor)
            
        }
    }
}

func radians(_ degrees: CGFloat) -> CGFloat {
    return degrees * (CGFloat.pi / 180.0)
}




extension UIView {
    var rotation:CGFloat {
        get {
            return atan2(self.transform.b, self.transform.a);
        }
        set {
            let rads = radians(newValue)
            var tr_p = self.transform
            tr_p.a =  cos(rads)
            tr_p.b =  sin(rads)
            tr_p.c = -sin(rads)
            tr_p.d =  cos(rads)
            self.transform = tr_p
        }
    }
}

