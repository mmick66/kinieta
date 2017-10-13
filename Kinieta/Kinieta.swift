//
//  Kinieta.swift
//  Kinieta
//
//  Created by Michael Michailidis on 11/10/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

class Kinieta: Action {
    
    private var mainSequence = Sequence()
    
    let view: UIView
    init(for view: UIView) {
        self.view = view
    }
    
    @discardableResult
    func move(to moves: [String:Any], during duration: TimeInterval) -> Kinieta {
        mainSequence.add(.Animation(self.view, moves, duration, nil, nil))
        return self
    }
    
    
    @discardableResult
    func wait(for time: TimeInterval, complete: Block? = nil) -> Kinieta {
        mainSequence.add(.Pause(time, complete))
        return self
    }
    
    @discardableResult
    func delay(for time: TimeInterval) -> Kinieta {
        guard let last = self.mainSequence.popLast() else {
            return self
        }
        let pause = ActionType.Pause(time, nil)
        let sequence = ActionType.Sequence([pause, last], nil)
        self.mainSequence.add(sequence)
        
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
        guard let lastAction = self.mainSequence.popLast() else {
            return self
        }
        switch lastAction {
        case .Animation(let view, let moves, let duration, _, let complete):
            let easing = Easing.get(type, place) ?? Easing.Linear
            self.mainSequence.add(.Animation(view, moves, duration, easing, complete))
        default:
            self.mainSequence.add(lastAction) // put back
        }
        
        return self
    }
    

    @discardableResult
    func group() -> Kinieta {
    
        var actions = [ActionType]()
        while let last = self.mainSequence.popLast() {
            switch last {
            case .Group: break
            default:     actions.append(last)
            }
            
        }
    
        let group = ActionType.Group(actions, nil)
        self.mainSequence.add(group)
    
        return self
    }
    

    @discardableResult
    func complete(_ block: @escaping Block) -> Kinieta {
        guard let last = self.mainSequence.popLast() else {
            return self
        }
        switch last {
        case .Animation(let view, let moves, let duration, let easing, _):
            self.mainSequence.add(ActionType.Animation(view, moves, duration, easing, block))
        case .Pause(let time, _):
            self.mainSequence.add(ActionType.Pause(time, block))
        case .Group(let list, let block):
            self.mainSequence.add(ActionType.Group(list, block))
        case .Sequence(let list, let block):
            self.mainSequence.add(ActionType.Sequence(list, block))
        }
        
        
        return self
    }
    
    func update(_ frame: Engine.Frame) -> ActionResult {
        return self.mainSequence.update(frame)
    }
}
