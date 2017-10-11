//
//  Group.swift
//  Kinieta
//
//  Created by Michael Michailidis on 10/09/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

class Group: Collection {
    
    var currentActions: [Action]?
    
    @discardableResult
    override func update(_ frame: Engine.Frame) -> Result {
        
        if var currentActions = self.currentActions {
            
            for (i,currentAction) in currentActions.enumerated() {
                switch currentAction.update(frame) {
                case .Running: continue
                case .Finished:
                    currentActions.remove(at: i)
                }
            }
            self.currentActions = currentActions
            return currentActions.count > 0 ? .Running : .Finished
        }
        else if actions.count > 0 {
            self.currentActions = actions.map { Factory.Action(for: self.view, with: $0) }
            return update(frame)
        }
        
        return .Finished
    }
    
}
