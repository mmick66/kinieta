//
//  Group.swift
//  Kinieta
//
//  Created by Michael Michailidis on 10/09/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

class Group: Action {
    
    var actions: [Action]
    
    init(_ actions: [Action]) {
        self.actions = actions
    }

    @discardableResult
    override func update(_ frame: Engine.Frame) -> Result {
        
        guard self.actions.count > 0 else {
            return .Finished
        }
        
        for action in actions {
            switch action.update(frame)  {
            case .Running:
                return .Running
            case .Finished:
                self.actions.removeFirst()
            }
        }
        
        return self.actions.count > 0 ? .Running : .Finished
        
    }
    
}
