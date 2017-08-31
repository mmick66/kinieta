//
//  Transformations.swift
//  Kinieta
//
//  Created by Michael Michailidis on 31/08/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit


struct Transformation {
    
    var cgAffineTransform: CGAffineTransform = CGAffineTransform.identity
    
    init(_ dict: Properties) {
        for (k,v) in dict {
            setProperty(p: k, v: v)
        }
    }
    
    private mutating func setProperty(p:String, v:Double) {
        
        let cgFloatValue = CGFloat(v)
        switch p.lowercased() {
        case "x":
            cgAffineTransform = cgAffineTransform.translatedBy(x: cgFloatValue, y: 0.0)
        case "y":
            cgAffineTransform = cgAffineTransform.translatedBy(x: 0.0, y: cgFloatValue)
        case "r":
            let radiansValue = cgFloatValue * (CGFloat.pi / 180.0)
            cgAffineTransform = cgAffineTransform.rotated(by: radiansValue)
        case "w":
            cgAffineTransform = cgAffineTransform.scaledBy(x: cgFloatValue, y: 0.0)
        case "h":
            cgAffineTransform = cgAffineTransform.scaledBy(x: 0.0, y: cgFloatValue)
        default:
            break
        }
    }
}
