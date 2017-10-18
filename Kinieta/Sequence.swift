/*
 * Sequence.swift
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

class Sequence: Collection, Action {
    
    let complete: Block?
    
    init(_ types: [ActionType] = [], complete: Block? = nil) {
        self.complete = complete
        super.init(types)
    }
    
    func popLast() -> ActionType? {
        return super.pop()
    }
    
    func popFirst() -> ActionType? {
        guard let first = self.types.first else { return nil }
        self.types.removeFirst()
        return first
    }
    
    func popAllUnGrouped() -> [ActionType] {
        var actions = [ActionType]()
        pop: while let last = self.popLast() {
            switch last {
            case .Group:
                self.add(last) // put back
                break pop
            default:
                actions.append(last)
            }
        }
        
        return actions
    }
    
    private var currentAction: Action?
    func update(_ frame: Engine.Frame) -> ActionResult {
        
        if let currentAction = self.currentAction {
            switch currentAction.update(frame) {
            case .Running:
                return .Running
            case .Finished:
                self.currentAction = nil
                return self.types.count > 0 ? .Running : .Finished
            }
        }
        else if let nextAction = self.popFirstAction() {
            self.currentAction = nextAction
            return update(frame)
        }
        
        self.complete?()
        return .Finished
    }
}
