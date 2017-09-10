//
//  Engine.swift
//  Kinieta
//
//  Created by Michael Michailidis on 06/09/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

class Engine {
    
    struct Frame {
        var timestamp: Double
        var duration: Double
        init(_ timestamp: Double, _ duration:Double) {
            self.timestamp  = timestamp
            self.duration   = duration
        }
    }
    
    static let shared = Engine()
    
    private var displayLink: CADisplayLink?
    
    private var actions: [Action] = []
    
    func add(_ action: Action) {
        
        actions.append(action)
        
        if displayLink == nil {
            displayLink = CADisplayLink(target: self, selector: #selector(Engine.update(_:)))
            displayLink?.add(to: RunLoop.current, forMode: RunLoopMode.commonModes)
        }
    }
    
    @objc func update(_ displayLink: CADisplayLink) {
        
        guard let action = self.actions.first else {
            return
        }
        
        let frame = Engine.Frame(displayLink.timestamp, displayLink.duration)
        if action.update(frame) {
            
            if let index = actions.index(where: { $0 === action }) {
                actions.remove(at: index)
            }
            
            if actions.count == 0 {
                self.displayLink?.invalidate()
                self.displayLink = nil
            }
        }
        
    }
    
    func pause() {
        displayLink?.isPaused = true
    }
    
    func resume() {
        displayLink?.isPaused = false
    }
    
    func stop() {
        displayLink?.invalidate()
    }
    
    func index(_ action: Action) -> Int? {
        if let index = actions.index(where: { $0 === action }) {
            return index
        }
        return nil
    }
    
    private var ipeg: Int = 0
    func peg() {
        ipeg = actions.count
    }
    
    func group() -> Group? {
        let bundle = Array(actions[ipeg..<actions.count])
        guard let group = Group(bundle) else {
            return nil
        }
        self.actions = Array(actions[0..<ipeg])
        self.actions.append(group)
        return group
    }
    
    deinit {
        self.stop()
    }
    
}



