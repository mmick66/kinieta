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
    
    private(set) var easing: Bezier
    
    private(set) var duration: TimeInterval
    private(set) var currentt: TimeInterval = 0.0
    
    var complete: Block?
    
    var initial: [String: Any]?
    
    init(_ view: UIView, moves: [String: Any], duration: TimeInterval, easing: Bezier?, complete: (()->Void)?) {
        
        self.duration   = duration
        self.easing     = easing ?? Easing.Linear
        self.complete   = complete
        
        for (property, value) in moves {
            let transformation = createTransormation(in: view, for: property, with: value)
            transformations.append(transformation)
        }
    }
    
    func update(_ frame: Engine.Frame) -> ActionResult {
        
        guard duration > 0.0 else {
            for transformation in transformations {
                transformation(1.0)
            }
            return .Finished
        }
        
        currentt += frame.duration
        currentt  = currentt > duration ? duration : currentt
        
        let tpoint = currentt / duration
        let ypoint = self.easing.solve(tpoint)
        for transformation in transformations {
            transformation(ypoint)
        }
        
        if tpoint == 1.0 { // reached end
            self.complete?()
            return .Finished
        }
        
        return .Running
        
    }
    
}



