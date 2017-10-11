//
//  Pause.swift
//  Kinieta
//
//  Created by Michael Michailidis on 10/09/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

class Pause: Action {
    
    let duration: TimeInterval
    let complete: Block?
    
    var currentt: TimeInterval = 0.0
    
    init(_ duration: TimeInterval, complete: Block?) {
        self.duration = duration
        self.complete = complete
    }
    
    func update(_ frame: Engine.Frame) -> ActionResult {
        
        guard duration > 0.0 else {
            return .Finished
        }
        
        currentt += frame.duration
        
        if currentt >= duration {
            self.complete?()
            return .Finished
        }
        
        return .Running
        
    }
    
}
