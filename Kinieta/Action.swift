//
//  Kinieta.swift
//  Kinieta
//
//  Created by Michael Michailidis on 10/09/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

class Action {
    
    enum Result: String {
        case Running     = "Action.Result.Running"
        case Finished   = "Action.Result.Finished"
    }
    internal var timeframe: Range<TimeInterval> = 0.0..<0.0
    
    internal(set) var onComplete: () -> Void = {  }
    @discardableResult func complete(_ block: @escaping  () -> Void) -> Action {
        self.onComplete = block
        return self
    }
    
    @discardableResult func update(_ frame: Engine.Frame) -> Result {
        guard timeframe.contains(frame.timestamp) else {
            self.onComplete()
            return .Finished
        }
        return execute(frame) == true ? .Finished : .Running
    }
    
    internal func execute(_ frame: Engine.Frame) -> Bool {
        return true
    }
    
    
}


