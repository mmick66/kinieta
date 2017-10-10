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
    
    init(_ actions: [Action], complete: Block?) {
        self.actions = actions
        super.init()
        self.onComplete = complete
    }

    @discardableResult
    override func update(_ frame: Engine.Frame) -> Result {
        
        guard self.actions.count > 0 else {
            return .Finished
        }
        
        for (i,action) in actions.enumerated() {
            switch action.update(frame)  {
            case .Running:
                break
            case .Finished:
                self.actions.remove(at: i)
            }
        }
        
        return self.actions.count > 0 ? .Running : .Finished
        
    }
    
}
