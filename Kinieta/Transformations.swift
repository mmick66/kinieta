//
//  Interpolations.swift
//  Kinieta
//
//  Created by Michael Michailidis on 06/09/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit


func interpolation<T: CGFractionable>(from start:T, to end:T, block: @escaping (T) -> Void) -> TransformationBlock {
    return { factor in
        let cgFactor = CGFloat(factor)
        let iValue = (1.0 - cgFactor) * start + cgFactor * end
        block(iValue)
    }
}

typealias TransformationBlock = (Double) -> Void
func transormation(in view: UIView, for property:String, with value:Any) -> TransformationBlock {
    
    let cgFloatValue = CGFloat.parse(value) ?? 1.0
    
    switch property {
        
    case "x":
        return interpolation(from: view.x, to: cgFloatValue) { nValue in
            view.x = nValue
        }
        
    case "y":
        return interpolation(from: view.y, to: cgFloatValue) { nValue in
            view.y = nValue
        }
        
    case "w", "width":
        return interpolation(from: view.width, to: cgFloatValue) { nValue in
            view.width = nValue
        }
        
    case "h", "height":
        return interpolation(from: view.height, to: cgFloatValue) { nValue in
            view.height = nValue
        }
        
    case "r", "rotation":
        return interpolation(from: view.rotation, to: cgFloatValue) { nValue in
            view.rotation = nValue
        }
    case "frame":
        return interpolation(from: view.frame, to: value as! CGRect) { nValue in
            view.frame = nValue
        }
    case "a", "alpha":
        return interpolation(from: view.alpha, to: cgFloatValue) { nValue in
            view.alpha = nValue
        }
        
    case "bg", "background":
        let uwBackgroundColor = view.backgroundColor != nil ? view.backgroundColor! : UIColor.clear
        guard let fComponents = uwBackgroundColor.components, let tComponents = (value as! UIColor).components else {
            return { float in }
        }
        return interpolation(from: fComponents, to: tComponents) { iComponents in
            view.backgroundColor = UIColor(components: iComponents)
        }
        
    case "brc", "borderColor":
        let uwBackgroundColor = view.layer.borderColor != nil ? UIColor(cgColor: view.layer.borderColor!) : UIColor.clear
        guard let fComponents = uwBackgroundColor.components, let tComponents = (value as! UIColor).components else {
            return { float in }
        }
        return interpolation(from: fComponents, to: tComponents) { iComponents in
            view.layer.borderColor = UIColor(components: iComponents).cgColor
        }
        
    case "brw", "borderWidth":
        return interpolation(from: view.layer.borderWidth, to: cgFloatValue) { nValue in
            view.layer.borderWidth = nValue
        }
        
    case "crd", "cornerRadius":
        return interpolation(from: view.layer.borderWidth, to: cgFloatValue) { nValue in
            view.layer.borderWidth = nValue
        }
        
    default:
        return { _ in }
    }
    
}


