//
//  Transformations.swift
//  Kinieta
//
//  Created by Michael Michailidis on 31/08/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit



struct Matrix {
    
    var raw: CGAffineTransform = CGAffineTransform.identity
    init(_ dict:Properties) {
        for (k,v) in dict {
            setProperty(p: k, v: v)
        }
    }
    
    private mutating func setProperty(p:String, v:Double) {
        
        let cgFloatV = CGFloat(v)
        switch p.lowercased() {
        case "x":
            raw.a = cgFloatV
        case "y":
            raw.b = cgFloatV
        default:
            break
        }
    }
}
