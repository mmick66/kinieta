//
//  Sequence.swift
//  Kinieta
//
//  Created by Michael Michailidis on 09/10/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

class Sequence: Action {
    
    var actions = [Action]()
    let view: UIView
    init(view:UIView) {
        self.view = view
    }
    
    @discardableResult
    func move(_ dict: [String:Any], during duration: TimeInterval) -> Sequence {
        let animation = Animation(view: self.view, moves: dict, duration: duration)
        self.actions.append(animation)
        return self
    }
    
    @discardableResult
    func wait(for time: TimeInterval) -> Sequence {
        let pause = Pause(for: time)
        self.actions.append(pause)
        return self
    }
    
    @discardableResult
    func ease(_ curve: Bezier) -> Sequence {
        guard let animation = self.actions.last as? Animation else {
            return self
        }
        animation.easeCurve = curve
        return self
    }
    
    @discardableResult
    func group() -> Sequence {
        
        var actionsToGroup = [Action]()
        while let action = self.actions.popLast() {
            if action is Group {
                self.actions.append(action) // put back
                break
            }
            actionsToGroup.append(action)
        }
        
        let group = Group(actionsToGroup)
        self.actions.append(group)
        
        return self
    }
    
    @discardableResult
    override func update(_ frame: Engine.Frame) -> Result {
        
        guard let action = self.actions.first else {
            return .Finished
        }
        
        switch action.update(frame) {
        case .Running:
            return .Running
        case .Finished:
            self.actions.removeFirst()
            return self.actions.count > 0 ? .Running : .Finished
        }
        
    }
}
