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
    
    init(_ types: [ActionType] = [], complete: Block? = nil) {
        self.complete = complete
        super.init(types)
    }
    
    init(_ actions: [Action], complete: Block? = nil) {
        self.complete = complete
        super.init()
        self.currentActions = actions
    }
    
    func update(_ frame: Engine.Frame) -> ActionResult {
        
        if let currentActions = self.currentActions {
            var fidxs = [Int]()
            for (index,currentAction) in currentActions.enumerated() {
                switch currentAction.update(frame) {
                case .Running:  continue
                case .Finished: fidxs.append(index)
                }
            }
            
            self.currentActions = currentActions.enumerated().filter({ !fidxs.contains($0.offset) }).map({ $0.element })
            
            if self.currentActions!.count == 0 {
                self.complete?()
                return .Finished
            }
            
            return .Running
        }
        else if types.count > 0 {
            self.currentActions = self.popAllActions()
            return update(frame)
        }
        
        self.complete?()
        return .Finished
    }
    
}
