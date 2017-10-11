//
//  Collection.swift
//  Kinieta
//
//  Created by Michael Michailidis on 11/10/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

class Collection: Action {
    
    internal var actions: [ActionType]
    let view: UIView
    
    init(_ view: UIView, actions: [ActionType], complete: Block? = nil) {
        
        self.actions    = actions
        self.view       = view
        
        super.init()
        
        self.onComplete = complete
        
    }
    
    func popFirstAction() -> Action? {
        guard let type = self.actions.first else { return nil }
        let action = Factory.Action(for: self.view, with: type)
        self.actions.removeFirst()
        return action
    }
    
    func popAllActions() -> [Action] {
        var allActions = [Action]()
        while let action = self.popFirstAction() { allActions.append(action) }
        return allActions
    }
    
}
