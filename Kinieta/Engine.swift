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
    
    class DisplayLink {
        private var displayLink: CADisplayLink?
    
        func pause() {
            displayLink?.isPaused = true
        }
        
        func resume() {
            displayLink?.isPaused = false
        }
        
        var onUpdate:((Engine.Frame) -> Void)?
        func start(onUpdate: ((Engine.Frame) -> Void)? = nil) {
            guard displayLink == nil else {
                return
            }
            self.onUpdate = onUpdate
            displayLink = CADisplayLink(target: self, selector: #selector(DisplayLink.update(_:)))
            displayLink?.add(to: RunLoop.current, forMode: RunLoopMode.commonModes)
        }
        func stop() {
            self.displayLink?.invalidate()
            self.displayLink = nil
        }
        
        @objc func update(_ displayLink: CADisplayLink) {
            let frame = Engine.Frame(displayLink.timestamp, displayLink.duration)
            self.onUpdate?(frame)
        }
    }
    
    static let shared = Engine()
    
    let displayLink = Engine.DisplayLink()
    
    private var actions: [Action] = []
    
    // MARK: API
    func add(_ action: Action) {
        
        actions.append(action)
        displayLink.start() { frame in
            self.update(with: frame)
        }
    }
    
    func remove(_ action: Action) {
        guard let index = actions.index(where: { $0 === action }) else {
            return
        }
        actions.remove(at: index)
        if actions.count == 0 {
            displayLink.stop()
        }
    }
    
    
    func group(_ actions: [Action], complete: Block? = nil) {
        for a in actions { remove(a) }
        let g = Group(actions, complete: complete)
        self.add(g)
    }
    
    private func update(with frame: Engine.Frame) {
     
        for action in actions {
            switch action.update(frame) {
            case .Running:  continue
            case .Finished: self.remove(action)
            }
        }
    }
    
    deinit {
        displayLink.stop()
    }
    
}



