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
    
    let duration: TimeInterval
    var currentt: TimeInterval = 0.0
    
    init(view: UIView, moves: [String:Any], duration: TimeInterval) {
        self.duration = duration
        for (property, value) in moves {
            let transformation = createTransormation(in: view, for: property, with: value)
            transformations.append(transformation)
        }
    }
    
    override func update(_ frame: Engine.Frame) -> Result {
        
        guard duration > 0.0 else {
            for transformation in transformations {
                transformation(1.0)
            }
            return .Finished
        }
        
        currentt += frame.duration
        currentt  = currentt > duration ? duration : currentt
        
        let factor = 1.0 - (currentt / duration)
        
        for transformation in transformations {
            transformation(factor)
        }
        
        return factor < 1.0 ? .Running : .Finished
    }
    
    
    
    
}



