//
//  Sequence.swift
//  Kinieta
//
//  Created by Michael Michailidis on 09/10/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

class Sequence: Collection, Action {
    
    private var currentAction: Action?
    
    let complete: Block?
    
    init(_ view: UIView, actions: [ActionType], complete: Block? = nil) {
        self.complete = complete
        super.init(view, actions: actions)
    }
    
    func add(_ action: ActionType) {
        self.actions.append(action)
    }
    
    func popLast() -> ActionType? {
        guard let last = self.actions.last else { return nil }
        self.actions.removeLast()
        return last
    }
    
    func popFirst() -> ActionType? {
        guard let first = self.actions.first else { return nil }
        self.actions.removeFirst()
        return first
    }
    
    func update(_ frame: Engine.Frame) -> ActionResult {
        
        if let currentAction = self.currentAction {
            switch currentAction.update(frame) {
            case .Running:
                return .Running
            case .Finished:
                return actions.count > 0 ? .Running : .Finished
            }
        }
        else if let nextAction = self.popFirstAction() {
            self.currentAction = nextAction
            return update(frame)
        }
        
        self.complete?()
        return .Finished
    }
}
