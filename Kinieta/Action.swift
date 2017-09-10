//
//  Kinieta.swift
//  Kinieta
//
//  Created by Michael Michailidis on 10/09/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

class Action {
    
    let view:UIView
    
    init(_ view:UIView) {
        self.view = view
        Engine.shared.add(self)
    }
    
    func move(_ dict: [String:Any], during duration: TimeInterval) -> Action {
        return Animation(self.view).move(dict, during: duration)
    }
    
    func wait(for time: TimeInterval) -> Action {
        return Pause(self.view, for: time)
    }
    
    func group() -> Action? {
        return Engine.shared.group()
    }
    
    internal var timeframe: Range<TimeInterval> = 0.0..<0.0
    
    internal(set) var onComplete: () -> Void = { _ in }
    func complete(_ block: @escaping  () -> Void) -> Action {
        self.onComplete = block
        return self
    }
    
    func then() -> Action {
        Engine.shared.peg()
        return self
    }
    
    @discardableResult func update(_ frame: Engine.Frame) -> Bool {
        guard timeframe.contains(frame.timestamp) else {
            self.onComplete()
            return true
        }
        return execute(frame)
    }
    
    internal func execute(_ frame: Engine.Frame) -> Bool {
        return true
    }
    
    internal func setTimeframe(for timeDuration: TimeInterval) {
        let currentMediaTime = CACurrentMediaTime()
        self.timeframe = currentMediaTime..<(currentMediaTime+timeDuration)
        
    }
}


