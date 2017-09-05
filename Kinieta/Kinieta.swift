//
//  Kinieta.swift
//  Kinieta
//
//  Created by Michael Michailidis on 31/08/2017.
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


class Kinieta {
    
    static var associatedKey = "KinietaAssociatedKey"
    
    let view:UIView
    init(_ view:UIView) {
        self.view = view
        KinietaEngine.shared.add(self)
    }
    
    var transformations = [Transformation]()
    
    
    @discardableResult func update(_ frame: KinietaEngine.Frame) -> Bool {
        
        var finished = true
        
        for transformation in transformations {
            finished = finished && transformation.execute(for: frame.timestamp)
        }
        
        return finished
    }
    
    // MARK: API
    
    
    func move(_ dict: [String:Any], _ duration: TimeInterval) -> Kinieta {
        
        let startTime = CACurrentMediaTime()
        
        let m = Transformation(self.view, for: dict, from: startTime, to: startTime + duration)
        
        transformations.append(m)
        
        return self
    }
    
    func snap(_ dict: [String:Any]) -> Kinieta {
        
        
        return self
    }
    
    private var waiting: TimeInterval = 0.0
    func wait(_ time: TimeInterval) -> Kinieta {
        
        waiting = time
        
        return self
    }
    
    func group() -> Kinieta {
        return Kinieta(self.view)
    }
}

extension UIView {
    
    func move(_ dict: [String:Any], _ duration: TimeInterval = 0.0) -> Kinieta {
        return Kinieta(self).move(dict, duration)
    }
    
}
