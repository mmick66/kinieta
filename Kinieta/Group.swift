//
//  Group.swift
//  Kinieta
//
//  Created by Michael Michailidis on 10/09/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

class Group: Action {
    
    var actionsQueue: [ActionType]
    var currentActions: [Action]?
    let view: UIView
    init(_ view: UIView, actions: [ActionType], complete: Block?) {
        self.actionsQueue = actions
        self.view = view
        super.init()
        self.onComplete = complete
        
    }

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
        else if actionsQueue.count > 0 {
            self.currentActions = actionsQueue.map { Factory.Action(for: self.view, with: $0) }
            return update(frame)
        }
        
        return .Finished
    }
    
}
