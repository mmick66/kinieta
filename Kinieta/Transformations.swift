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
            return createInterpolation(from: self.view.center.x, to: cgFloatValue) { nValue in
                self.view.center = CGPoint(x: nValue, y: self.view.center.y)
            }
            
        case "y":
            return createInterpolation(from: self.view.center.x, to: cgFloatValue) { nValue in
                self.view.center = CGPoint(x: self.view.center.x, y: nValue)
            }
            
        case "w", "width":
            return createInterpolation(from: self.view.frame.size.width, to: cgFloatValue) { nValue in
                var oFrame = self.view.frame
                oFrame.size.width = nValue
                self.view.frame = oFrame
            }
            
        case "h", "height":
            return createInterpolation(from: self.view.frame.size.height, to: cgFloatValue) { nValue in
                var oFrame = self.view.frame
                oFrame.size.height = nValue
                self.view.frame = oFrame
            }
            
        case "r", "rotation":
            return createInterpolation(from: self.view.rotation, to: cgFloatValue) { nValue in
                self.view.rotation = nValue
            }
            
        case "a", "alpha":
            return createInterpolation(from: self.view.alpha, to: cgFloatValue) { nValue in
                self.view.alpha = cgFloatValue
            }
            
        case "b", "background":
            return createInterpolation(from: 0.0, to: 1.0) { nValue in
                
            }
            
        default:
            return { _ in
                
            }
        }

    }
    
    private func createInterpolation(from start:CGFloat, to end:CGFloat, block: @escaping (CGFloat) -> Void) -> TransformationBlock {
        
        return { factor in
            let cgFloatFactor = CGFloat(factor)
            let iv = (1.0 - cgFloatFactor) * start + cgFloatFactor * end
            block(iv)
            
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

