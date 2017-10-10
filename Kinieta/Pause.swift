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
    var currentt: TimeInterval = 0.0
    init(for duration: TimeInterval) {
        self.duration = duration
    }
    
    @discardableResult
    override func update(_ frame: Engine.Frame) -> Result {
        
        guard duration > 0.0 else {
            return .Finished
        }
        currentt += frame.duration
        return currentt < duration ? .Running : .Finished
    }
    
}
