//
//  Sequence.swift
//  Kinieta
//
//  Created by Michael Michailidis on 09/10/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

class Sequence: Collection, Action {
    
    let complete: Block?
    
    init(_ actions: [ActionType] = [], complete: Block? = nil) {
        self.complete = complete
        super.init(actions)
    }
    
    func popLast() -> ActionType? {
        guard let last = self.types.last else { return nil }
        self.types.removeLast()
        return last
    }
    
    func popFirst() -> ActionType? {
        guard let first = self.types.first else { return nil }
        self.types.removeFirst()
        return first
    }
    
    private var currentAction: Action?
    func update(_ frame: Engine.Frame) -> ActionResult {
        
        if let currentAction = self.currentAction {
            switch currentAction.update(frame) {
            case .Running:
                return .Running
            case .Finished:
                self.currentAction = nil
                return self.types.count > 0 ? .Running : .Finished
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
