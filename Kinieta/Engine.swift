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
    
    private var groups: [Group] = []
    
    func add(_ animation: Animation) {
        
        groups.append(Group(animation))
        
        if displayLink == nil {
            displayLink = CADisplayLink(target: self, selector: #selector(Engine.update(_:)))
            displayLink?.add(to: RunLoop.current, forMode: RunLoopMode.commonModes)
        }
    }
    
    @objc func update(_ displayLink: CADisplayLink) {
        
        guard let group = self.groups.first else {
            return
        }
        
        if group.update(Engine.Frame(displayLink.timestamp, displayLink.duration)) {
            
            if let index = groups.index(where: { $0 === group }) {
                groups.remove(at: index)
            }
            
            if groups.count == 0 {
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
    
    deinit {
        self.stop()
    }
    
}


class Group {
    
    private(set) var animations:[Animation] = []
    
    init(_ animation:Animation) {
        self.add(animation)
    }
    
    func add(_ animation:Animation) {
        self.animations.append(animation)
    }
    func remove(_ member:Animation) {
        
    }
    @discardableResult func update(_ frame: Engine.Frame) -> Bool {
        
        var allComplete = true
        
        for animation in animations {
            
            switch animation.update(frame) {
                case true: animation.onComplete()
                case false: allComplete = false
            }
        }
        
        if allComplete {
            self.onComplete()
            return true
        }
        
        return false
    }
    
    private(set) var onComplete: () -> Void = { _ in }
    func complete(_ block: @escaping  () -> Void) {
        
        self.onComplete = block
        
    }
}
