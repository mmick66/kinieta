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
            return createInterpolation(from: 0, to: cgFloatValue) { nValue in
                
            }
            
        default:
            return { _ in
                
            }
        }

    }
    
    private func createInterpolation(from start:CGFloat, to end:CGFloat, block: @escaping (CGFloat) -> Void) -> TransformationBlock {
        
        return { factor in
            let cgFactor = CGFloat(factor)
            let iv = (1.0 - cgFactor) * start + cgFactor * end
            block(iv)
            
        }
    }
}


extension UIView {
    var rotation:CGFloat {
        get {
            return 0.0
        }
        set {
            
        }
    }
}

