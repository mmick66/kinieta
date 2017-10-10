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
        addInQueue(.Animation(moves, duration, nil, nil))
        return self
    }
    
    
    @discardableResult
    func wait(for time: TimeInterval, complete: Block? = nil) -> Sequence {
        addInQueue(.Pause(time, complete))
        return self
    }
    
    private func addInQueue(_ action: Action.ActionType) {
        actionsQueue.append(action)
        if currentAction == nil { prepareNextAction() }
    }
    
    @discardableResult
    func delay(for time: TimeInterval) -> Sequence {
        guard let lastAction = actionsQueue.popLast() else {
            return self
        }
        let pauseAction = Action.ActionType.Pause(time, nil)
        actionsQueue.append(pauseAction)
        actionsQueue.append(lastAction)
        
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
        case .Animation(let moves, let duration, _, let complete):
            let easing = Easing.get(type, place) ?? Easing.Linear
            self.actionsQueue.append(.Animation(moves, duration, easing, complete))
        default:
            self.actionsQueue.append(lastAction) // put back
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
    override func complete(_ block: @escaping Block) -> Action {
        guard let lastAction = actionsQueue.popLast() else {
            return self
        }
        switch lastAction {
        case .Animation(let moves, let duration, let easing, _):
            self.currentAction = Animation(self.view, moves: moves, duration: duration, easing: easing, complete: block)
        case .Pause(let time, _):
            self.currentAction = Pause(time, complete: block)
        case .Group(let types, let block):
            let actions = types.map { (type) -> Action in return self.prepareAction(type) }
            self.currentAction = Group(actions, complete: block)
        }
        
        return self
    }
    
    private var currentAction: Action?
    
    @discardableResult
    private func prepareNextAction() -> Bool {
        guard let nextActionType = self.actionsQueue.first else {
            return false
        }
        self.currentAction = self.prepareAction(nextActionType)
        self.actionsQueue.removeFirst()
        return true
        
    }
    
    private func prepareAction(_ type: ActionType) -> Action {
        switch type {
        case .Animation(let moves, let duration, let easing, let block):
            return Animation(self.view, moves: moves, duration: duration, easing: easing, complete: block)
        case .Pause(let time, let block):
            return Pause(time, complete: block)
        case .Group(let types, let block):
            let actions = types.map { (type) -> Action in return self.prepareAction(type) }
            return Group(actions, complete: block)
        }
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
