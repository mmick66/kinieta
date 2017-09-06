//
//  Engine.swift
//  Kinieta
//
//  Created by Michael Michailidis on 06/09/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

class KinietaEngine {
    
    struct Frame {
        var timestamp: Double
        var duration: Double
        init(_ timestamp: Double, _ duration:Double) {
            self.timestamp  = timestamp
            self.duration   = duration
        }
    }
    
    struct Scene<T> {
        let content:T
        init(_ content:T) {
            self.content = content
        }
    }
    
    static let shared = KinietaEngine()
    
    private var displayLink: CADisplayLink?
    
    private var instances: [Kinieta] = []
    
    func add(_ instance: Kinieta) {
        
        instances.append(instance)
        
        if displayLink == nil {
            displayLink = CADisplayLink(target: self, selector: #selector(KinietaEngine.update(_:)))
            displayLink?.add(to: RunLoop.current, forMode: RunLoopMode.commonModes)
        }
    }
    
    func remove(_ instance: Kinieta) {
        
        if let index = instances.index(where: { $0 === instance }) {
            instances.remove(at: index)
        }
        
        if instances.count == 0 {
            displayLink?.invalidate()
            displayLink = nil
        }
    }
    
    @objc func update(_ displayLink: CADisplayLink) {
        
        guard let current = self.instances.last else {
            return
        }
        
        let frame = KinietaEngine.Frame(displayLink.timestamp, displayLink.duration)
        
        let finished = current.update(frame)
        
        if finished {
            self.remove(current)
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
    
    deinit {
        self.stop()
    }
    
}
