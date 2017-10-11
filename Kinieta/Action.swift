//
//  Kinieta.swift
//  Kinieta
//
//  Created by Michael Michailidis on 10/09/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

typealias Block = (()->Void)

class Action {
    
    enum Result: String {
        case Running     = "Action.Result.Running"
        case Finished   = "Action.Result.Finished"
    }
    
    internal var onComplete: (()->Void)?
    @discardableResult
    func complete(_ block: @escaping  () -> Void) -> Action {
        self.onComplete = block
        return self
    }
    
    @discardableResult
    func update(_ frame: Engine.Frame) -> Result {
        return .Finished
    }
    
}

enum ActionType {
    case Animation(Dictionary<String,Any>, TimeInterval, Bezier?, Block?)
    case Pause(TimeInterval, Block?)
    case Group([ActionType], Block?)
}

class Factory {
    
    let shared = Factory()
    
    static func Action(for view: UIView, with type: ActionType) -> Action {
        switch type {
        case .Animation(let moves, let duration, let easing, let block):
            return Animation(view, moves: moves, duration: duration, easing: easing, complete: block)
        case .Pause(let time, let block):
            return Pause(time, complete: block)
        case .Group(let types, let block):
            return Group(view, actions: types, complete: block)
        }
    }
}
