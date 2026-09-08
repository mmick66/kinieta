/*
 * Action.swift
 * Created by Michael Michailidis on 10/09/2017.
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

public typealias Block = () -> Void

/// A weak reference to the view an action targets, so a pending timeline never
/// keeps a view alive. An animation whose view has gone finishes immediately.
struct ViewRef {
    weak var view: UIView?
    init(_ view: UIView?) { self.view = view }
}

/// The description of an action before it runs. A timeline is a tree of these;
/// they are turned into live `Action` objects when their turn comes.
enum ActionType: CustomStringConvertible {
    case animation(ViewRef, [Property], TimeInterval, Bezier?, Block?)
    case pause(TimeInterval, Block?)
    case group([ActionType], Block?)
    case sequence([ActionType], Block?)

    var description: String {
        switch self {
        case .animation(_, let properties, _, _, _):
            return "Animation (\(properties.map(\.name).joined(separator: " ")))"
        case .pause(let time, _):
            return "Pause (\(time))"
        case .group(let types, _):
            return "Group (\(types.count))"
        case .sequence(let types, _):
            return "Sequence (\(types.count))"
        }
    }

    @MainActor
    func makeAction() -> Action {
        switch self {
        case .animation(let ref, let properties, let duration, let easing, let block):
            return Animation(ref, properties: properties, duration: duration, easing: easing, complete: block)
        case .pause(let time, let block):
            return Pause(time, complete: block)
        case .group(let list, let block):
            return Group(list, complete: block)
        case .sequence(let list, let block):
            return Sequence(list, complete: block)
        }
    }
}

enum ActionResult {
    case running
    case finished
}

/// Something the engine advances once per frame.
@MainActor
protocol Action: AnyObject {
    func update(_ frame: Engine.Frame) -> ActionResult
}
