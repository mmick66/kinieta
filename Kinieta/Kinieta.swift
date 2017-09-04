//
//  Kinieta.swift
//  Kinieta
//
//  Created by Michael Michailidis on 31/08/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

protocol Kinieta {
    func move(_ dict: [String:Any], _ time: TimeInterval) -> Kinieta
}

class KinietaEngine {
    
    static let shared = KinietaEngine()
    
    private var displayLink: CADisplayLink?
    
    
    private var instances: [KinietaInstance] = []
    
    init() {
        
    }
    
    func add(_ instance: KinietaInstance) {
        
        instances.append(instance)
        
        if displayLink == nil {
            displayLink = CADisplayLink(target: self, selector: #selector(KinietaEngine.update(_:)))
            displayLink?.add(to: RunLoop.current, forMode: RunLoopMode.commonModes)
        }
    }
    
    @objc func update(_ displayLink: CADisplayLink) {
        
    }
}

class KinietaInstance: Kinieta {
    
    static var associatedKey = "KinietaAssociatedKey"
    enum State {
        case stopped
        case moving(start: TimeInterval)
        case waiting(time: TimeInterval)
    }
    var state: State = .stopped
    
    let view:UIView
    init(_ view:UIView) {
        self.view = view
    }
    
    var transformations = [Transformation]()
    
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

extension UIView: Kinieta {
    
    func move(_ dict: [String:Any], _ time: TimeInterval = 0.5) -> Kinieta {
        return KinietaInstance(self).move(dict, time)
    }
    
}
