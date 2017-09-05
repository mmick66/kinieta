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
        
        for instance in instances {
            let frame = KinietaEngine.Frame(displayLink.timestamp, displayLink.duration)
            let finished = instance.update(frame)
            if finished {
                self.remove(instance)
            }
        }
    }
    
    deinit {
        displayLink?.invalidate()
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
        
        return false
    }
    
    // MARK: API
    
    
    func move(_ dict: [String:Any], _ time: TimeInterval) -> Kinieta {
        
        let m = Transformation(self.view, for: dict)
        
        transformations.append(m)
        
        return self
    }
    
    func snap(_ dict: [String:Any]) -> Kinieta {
        
        
        return self
    }
    
    func wait(_ time:TimeInterval) -> Kinieta {
        
        
        return self
    }
    
    
//    func group() -> Kinieta {
//        
//        
//    }
}

extension UIView {
    
    func move(_ dict: [String:Any], _ time: TimeInterval = 0.5) -> Kinieta {
        return Kinieta(self).move(dict, time)
    }
    
}
