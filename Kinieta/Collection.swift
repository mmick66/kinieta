//
//  Collection.swift
//  Kinieta
//
//  Created by Michael Michailidis on 11/10/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

class Collection {
    
    internal var types: [ActionType]
    
    init(_ actions: [ActionType]) {
        self.types = actions
    }
    
    var first: ActionType? {
        get {
            return self.types.first
        }
    }
    var last: ActionType? {
        get {
            return self.types.last
        }
    }
    
    func add(type: ActionType) {
        self.types.append(type)
    }
    
    func popFirstAction() -> Action? {
        guard let type = self.types.first else { return nil }
        let action = Factory.Action(from: type)
        self.types.removeFirst()
        return action
    }
    
    func popAllActions() -> [Action] {
        var allActions = [Action]()
        while let action = self.popFirstAction() { allActions.append(action) }
        return allActions
    }
    
}
