//
//  Kinieta.swift
//  Kinieta
//
//  Created by Michael Michailidis on 11/10/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

class Kinieta: Action {
    
    private var main: Sequence
    
    let view: UIView
    init(for view: UIView) {
        self.view = view
        self.main = Sequence(view, actions: [])
    }
    
    @discardableResult
    func move(_ moves: [String:Any], during duration: TimeInterval) -> Kinieta {
        self.main.add(.Animation(moves, duration, nil, nil))
        return self
    }
    
    
    @discardableResult
    func wait(for time: TimeInterval, complete: Block? = nil) -> Kinieta {
        self.main.add(.Pause(time, complete))
        return self
    }
    
    @discardableResult
    func delay(for time: TimeInterval) -> Kinieta {
        guard let last = self.main.popLast() else {
            return self
        }
        let pause = ActionType.Pause(time, nil)
        let sequence = ActionType.Sequence([pause, last], nil)
        self.main.add(sequence)
        
        return self
    }
    
    // MARK: Easing Functions
    @discardableResult
    func easeIn(_ type: Easing.Types = Easing.Types.Quad) -> Kinieta {
        return self.ease(type, "In")
    }
    
    @discardableResult
    func easeOut(_ type: Easing.Types = Easing.Types.Quad) -> Kinieta {
        return self.ease(type, "Out")
    }
    
    @discardableResult
    func easeInOut(_ type: Easing.Types = Easing.Types.Quad) -> Kinieta {
        return self.ease(type, "InOut")
    }
    
    private func ease(_ type: Easing.Types, _ place: String) -> Kinieta {
        guard let lastAction = self.main.popLast() else {
            return self
        }
        switch lastAction {
        case .Animation(let moves, let duration, _, let complete):
            let easing = Easing.get(type, place) ?? Easing.Linear
            self.main.add(.Animation(moves, duration, easing, complete))
        default:
            self.main.add(lastAction) // put back
        }
        
        return self
    }
    
    // MARK: Group
    //    @discardableResult
    //    func group() -> Sequence {
    //
    //        var actionsToGroup = [Action]()
    //        while let actionType = self.actions.popLast() {
    //            if action is Group {
    //                self.actions.append(action) // put back
    //                break
    //            }
    //            actionsToGroup.append(action)
    //        }
    //
    //        let group = Group(actionsToGroup)
    //        self.actions.append(group)
    //
    //        return self
    //    }
    
    //    // MARK: Update
    
    @discardableResult
    func complete(_ block: @escaping Block) -> Kinieta {
//        guard let lastAction = self.main.popLast() else {
//            return self
//        }
//        switch lastAction {
//        case .Animation(let moves, let duration, let easing, _):
//            self.currentAction = Animation(self.view, moves: moves, duration: duration, easing: easing, complete: block)
//        case .Pause(let time, _):
//            self.currentAction = Pause(time, complete: block)
//        case .Group(let types, let block):
//            self.currentAction = Group(self.view, actions: types, complete: block)
//        }
        
        return self
    }
    
    func update(_ frame: Engine.Frame) -> ActionResult {
        return self.main.update(frame)
    }
}
