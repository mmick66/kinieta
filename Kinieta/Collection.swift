/*
 * Collection.swift
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

class Collection {
    
    internal var types: [ActionType]
    
    init(_ types: [ActionType] = []) {
        self.types = types
    }
    
    var first: ActionType? {
        get {
            return self.types.first
        }
    }
    var last: ActionType? {
        get {
            return self.types.last
        }
    }
    
    func add(_ type: ActionType) {
        self.types.append(type)
    }
    
    func pop() -> ActionType? {
        guard let last = self.types.last else { return nil }
        self.types.removeLast()
        return last
    }
    
    func popFirstAction() -> Action? {
        guard let type = self.types.first else { return nil }
        let action = Factory.Action(from: type)
        self.types.removeFirst()
        return action
    }
    
    func popAllActions() -> [Action] {
        var allActions = [Action]()
        while let action = self.popFirstAction() { allActions.append(action) }
        return allActions
    }
    
}
