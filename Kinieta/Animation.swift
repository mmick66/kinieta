//
//  Kinieta.swift
//  Kinieta
//
//  Created by Michael Michailidis on 31/08/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit


class Animation: Action {
    
    private var transformations:[TransformationBlock] = []
    
    internal var easeCurve: Bezier = Easing.liner
    
    init(view: UIView, moves: [String:Any], duration: TimeInterval) {
        
        for (property, value) in moves {
            let transformation = createTransormation(in: view, for: property, with: value)
            transformations.append(transformation)
        }
    }
    
    override func execute(_ frame: Engine.Frame) -> Bool {
        
        let factor = (frame.timestamp - timeframe.lowerBound) / (timeframe.upperBound - timeframe.lowerBound)
        
        for transformation in transformations {
            transformation(factor)
        }
        
        return false
    }
    
    
    
}



