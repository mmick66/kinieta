//
//  Kinieta.swift
//  Kinieta
//
//  Created by Michael Michailidis on 31/08/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit


struct Frame {
    var timestamp: Double
    var duration: Double
}

class KinietaEngine {
    
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
    
    @objc func update(_ displayLink: CADisplayLink) {
        
        for instance in instances {
            let frame = Frame(timestamp: displayLink.timestamp, duration: displayLink.duration)
            instance.update(frame)
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
    
    
    func update(_ frame: Frame) {
        
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
