//
//  Kinieta.swift
//  Kinieta
//
//  Created by Michael Michailidis on 10/09/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

typealias Block = (()->Void)

enum ActionType {
    case Animation(UIView, Dictionary<String,Any>, TimeInterval, Bezier?, Block?)
    case Pause(TimeInterval, Block?)
    case Group([ActionType], Block?)
    case Sequence([ActionType], Block?)
}

enum ActionResult: String {
    case Running    = "ActionResult.Running"
    case Finished   = "ActionResult.Finished"
}

protocol Action {
    func update(_ frame: Engine.Frame) -> ActionResult
}

class Factory {
    
    let shared = Factory()
    
    static func Action(from type: ActionType) -> Action {
        switch type {
        case .Animation(let view, let moves, let duration, let easing, let block):
            return Animation(view, moves: moves, duration: duration, easing: easing, complete: block)
        case .Pause(let time, let block):
            return Pause(time, complete: block)
        case .Group(let list, let block):
            return Group(list, complete: block)
        case .Sequence(let list, let block):
            return Sequence(list, complete: block)
        }
    }
}
