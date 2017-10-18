/*
 * Action.swift
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

typealias Block = (()->Void)

enum ActionType: CustomStringConvertible {
    case Animation(UIView, Dictionary<String,Any>, TimeInterval, Bezier?, Block?)
    case Pause(TimeInterval, Block?)
    case Group([ActionType], Block?)
    case Sequence([ActionType], Block?)
    var description: String {
        switch self {
        case .Animation(_, let moves, _, _, _):
            return "Animation (\(moves.toString()))"
        case .Pause(let time, _):
            return "Pause (\(time))"
        case .Group(let types, _):
            return "Group (\(types.count))"
        case .Sequence(let types, _):
            return "Sequence (\(types.count))"
        }
    }
}

enum ActionResult: String {
    case Running    = "ActionResult.Running"
    case Finished   = "ActionResult.Finished"
}

protocol Action: class {
    func update(_ frame: Engine.Frame) -> ActionResult
}

class Factory {
    
    let shared = Factory()
    
    static func Action(from type: ActionType) -> Action {
        switch type {
        case .Animation(let view, let moves, let duration, let easing, let block):
            return Animation(view, moves: moves, duration: duration, easing: easing, complete: block)
        case .Pause(let time, let block):
            return Pause(time, complete: block)
        case .Group(let list, let block):
            return Group(list, complete: block)
        case .Sequence(let list, let block):
            return Sequence(list, complete: block)
        }
    }
}


