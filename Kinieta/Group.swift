//
//  Group.swift
//  Kinieta
//
//  Created by Michael Michailidis on 10/09/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

class Group: Collection, Action {
    
    var currentActions: [Action]?
    let complete: Block?
    
    init(_ view: UIView, actions: [ActionType], complete: Block? = nil) {
        self.complete = complete
        super.init(view, actions: actions)
    }
    
    func update(_ frame: Engine.Frame) -> ActionResult {
        
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
            self.currentActions = self.popAllActions()
            return update(frame)
        }
        
        self.complete?()
        return .Finished
    }
    
}
