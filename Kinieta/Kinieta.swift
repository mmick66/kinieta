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
        self.main = Sequence()
    }
    
    @discardableResult
    func move(to moves: [String:Any], during duration: TimeInterval) -> Kinieta {
        self.main.add(.Animation(self.view, moves, duration, nil, nil))
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
        case .Animation(let view, let moves, let duration, _, let complete):
            let easing = Easing.get(type, place) ?? Easing.Linear
            self.main.add(.Animation(view, moves, duration, easing, complete))
        default:
            self.main.add(lastAction) // put back
        }
        
        return self
    }
    

    @discardableResult
    func group() -> Kinieta {
    
        var actions = [ActionType]()
        while let last = self.main.popLast() {
            switch last {
            case .Sequence, .Group:
                break
            default:
                actions.append(last)
            }
            
        }
    
        let group = ActionType.Group(actions, nil)
        self.main.add(group)
    
        return self
    }
    

    @discardableResult
    func complete(_ block: @escaping Block) -> Kinieta {
        guard let last = self.main.popLast() else {
            return self
        }
        switch last {
        case .Animation(let view, let moves, let duration, let easing, _):
            self.main.add(ActionType.Animation(view, moves, duration, easing, block))
        case .Pause(let time, _):
            self.main.add(ActionType.Pause(time, block))
        case .Group(let list, let block):
            self.main.add(ActionType.Group(list, block))
        case .Sequence(let list, let block):
            self.main.add(ActionType.Sequence(list, block))
        }
        
        
        return self
    }
    
    func update(_ frame: Engine.Frame) -> ActionResult {
        return self.main.update(frame)
    }
}
