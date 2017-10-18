/*
 * Group.swift
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

class Group: Collection, Action {
    
    var currentActions: [Action]?
    let complete: Block?
    
    init(_ types: [ActionType] = [], complete: Block? = nil) {
        self.complete = complete
        super.init(types)
    }
    
    init(_ actions: [Action], complete: Block? = nil) {
        self.complete = complete
        super.init()
        self.currentActions = actions
    }
    
    func update(_ frame: Engine.Frame) -> ActionResult {
        
        if let currentActions = self.currentActions {
            var fidxs = [Int]()
            for (index,currentAction) in currentActions.enumerated() {
                switch currentAction.update(frame) {
                case .Running:  continue
                case .Finished: fidxs.append(index)
                }
            }
            
            self.currentActions = currentActions.enumerated().filter({ !fidxs.contains($0.offset) }).map({ $0.element })
            
            if self.currentActions!.count == 0 {
                self.complete?()
                return .Finished
            }
            
            return .Running
        }
        else if types.count > 0 {
            self.currentActions = self.popAllActions()
            return update(frame)
        }
        
        self.complete?()
        return .Finished
    }
    
}
