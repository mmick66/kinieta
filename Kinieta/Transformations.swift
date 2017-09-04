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
    
    private var transformations:[TransformationBlock] = []
    
    init(_ view:UIView, for properties: [String:Any]) {
        
        self.view = view
        
        for (key, value) in properties {
            let transformation = createTransormation(of: key, for: value)
            transformations.append(transformation)
        }
    }
    
    func perform(for factor: Double) {
        
        for transformation in transformations {
            transformation(factor)
        }
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
            
        case "b", "background":
            return createColorInterpolation(from: self.view.backgroundColor ?? UIColor.white, to: value as! UIColor) { nColor in
                self.view.backgroundColor = nColor
            }
            
        case "borderColor":
            return createColorInterpolation(from: self.view.backgroundColor ?? UIColor.white, to: value as! UIColor) { nColor in
                self.view.layer.borderColor = nColor.cgColor
            }
            
        case "borderWidth":
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
            let ifloat = (1.0 - cgFloatFactor) * start + cgFloatFactor * end
            block(ifloat)
            
        }
    }
    
    private func createColorInterpolation(from start:UIColor, to end:UIColor, block: @escaping (UIColor) -> Void) -> TransformationBlock {
        
        return { factor in
            let cgFloatFactor = CGFloat(factor)
            let icolor = UIColor.interpolate(from: start, to: end, with: cgFloatFactor)
            block(icolor)
            
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

