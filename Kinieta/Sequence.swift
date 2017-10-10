//
//  Sequence.swift
//  Kinieta
//
//  Created by Michael Michailidis on 09/10/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

class Sequence: Action {
    
    var actionsQueue = [Action.ActionType]()
    
    let view: UIView
    init(view:UIView) {
        self.view = view
    }
    
    @discardableResult
    func move(_ moves: [String:Any], during duration: TimeInterval) -> Sequence {
        addInQueue(.Animation(moves, duration, nil))
        return self
    }
    
    
    @discardableResult
    func wait(for time: TimeInterval) -> Sequence {
        addInQueue(.Pause(time))
        return self
    }
    
    private func addInQueue(_ action: Action.ActionType) {
        actionsQueue.append(action)
        if currentAction == nil { prepareNextAction() }
    }
    
    @discardableResult
    func delay(for time: TimeInterval) -> Sequence {
        guard let lastAction = actionsQueue.last else {
            return self
        }
        
        switch lastAction {
        case .Animation(_, _, _):
            let pause = Action.ActionType.Pause(time)
            let index = actionsQueue.endIndex.advanced(by: -1)
            actionsQueue.insert(pause, at: index)
        default:
            break
        }
        
        return self
    }
    
    // MARK: Easing Functions
    @discardableResult
    func easeIn(_ type: Easing.Types = Easing.Types.Quad) -> Sequence {
        return self.ease(type, "In")
    }

    @discardableResult
    func easeOut(_ type: Easing.Types = Easing.Types.Quad) -> Sequence {
        return self.ease(type, "Out")
    }

    @discardableResult
    func easeInOut(_ type: Easing.Types = Easing.Types.Quad) -> Sequence {
        return self.ease(type, "InOut")
    }
    
    private func ease(_ type: Easing.Types, _ place: String) -> Sequence {
        guard let lastAction = self.actionsQueue.popLast() else {
            return self
        }
        switch lastAction {
        case .Animation(let moves, let duration, _):
            let easing = Easing.get(type, place) ?? Easing.Linear
            self.actionsQueue.append(.Animation(moves, duration, easing))
        default:
            self.actionsQueue.append(lastAction) // put back
        }
        
        return self
    }
//
//    // MARK: Group
//    @discardableResult
//    func group() -> Sequence {
//
//        var actionsToGroup = [Action]()
//        while let action = self.actions.popLast() {
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
//
//    // MARK: Update
    
    private var currentAction: Action?
    
    @discardableResult
    private func prepareNextAction() -> Bool {
        
        guard let nextAction = self.actionsQueue.first else {
            return false
        }
        
        switch nextAction {
        case .Animation(let moves, let duration, let easing):
            self.currentAction = Animation(self.view, moves: moves, duration: duration, easing: easing)
        case .Pause(let time):
            self.currentAction = Pause(time)
        }
        
        self.actionsQueue.removeFirst()
        
        return true
        
    }
    
    
    @discardableResult
    override func update(_ frame: Engine.Frame) -> Result {

        guard let action = self.currentAction else {
            return .Finished
        }
        
        switch action.update(frame) {
        case .Running:
            return .Running
        case .Finished:
            return self.prepareNextAction() ? .Running : .Finished
        }

    }
}
