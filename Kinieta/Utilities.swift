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
        
        let r = (1 - cgFloatFactor) * startComponents.r + cgFloatFactor * endComponents.r
        let g = (1 - cgFloatFactor) * startComponents.g + cgFloatFactor * endComponents.g
        let b = (1 - cgFloatFactor) * startComponents.b + cgFloatFactor * endComponents.b
        let a = (1 - cgFloatFactor) * startComponents.a + cgFloatFactor * endComponents.a
        
        let iColor = UIColor(red: r, green: g, blue: b, alpha: a)
        
        block(iColor)
        
    }
}

func radians(_ degrees: CGFloat) -> CGFloat {
    return degrees * (CGFloat.pi / 180.0)
}


