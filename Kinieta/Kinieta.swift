/*
 * Kinieta.swift
 * Created by Michael Michailidis on 16/10/2017.
 * http://blog.karmadust.com/
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

import UIKit

class Kinieta: Action {
    
    private(set) var mainSequence = Sequence()
    
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
    
    var then: Kinieta {
        let actions = self.mainSequence.popAllUnGrouped()
        guard actions.count > 0 else { return self }
        
        let sequence    = ActionType.Sequence(actions, nil)
        let group       = ActionType.Group([sequence], nil)
        self.mainSequence.add(group)
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
            let easing = Easing.Get(type, place) ?? Easing.Linear
            self.mainSequence.add(.Animation(view, moves, duration, easing, complete))
        default:
            self.mainSequence.add(lastAction) // put back
        }
        
        return self
    }
    

    @discardableResult
    func parallel() -> Kinieta {
    
        let actions = self.mainSequence.popAllUnGrouped()
        guard actions.count > 0 else { return self }
        
        let group = ActionType.Group(actions, nil)
        self.mainSequence.add(group)
        
        return self
    }
    
    @discardableResult
    func again(times: UInt8 = 1) -> Kinieta {
        let typesCopy = self.mainSequence.types
        for _ in 0..<times {
            for at in typesCopy {
                self.mainSequence.add(at)
            }
        }
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
        case .Group(let list, _):
            self.mainSequence.add(ActionType.Group(list, block))
        case .Sequence(let list, _):
            self.mainSequence.add(ActionType.Sequence(list, block))
        }
        
        
        return self
    }
    
    func update(_ frame: Engine.Frame) -> ActionResult {
        return self.mainSequence.update(frame)
    }
}
