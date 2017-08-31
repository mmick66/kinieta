//
//  Kinieta.swift
//  Kinieta
//
//  Created by Michael Michailidis on 31/08/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

typealias Properties = [String:Double]

open class Kinieta {
    
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
    
    var stack   = [Transformation]()
    
    // MARK: API
    
    func move(_ dict:Properties, time: TimeInterval? = 0.5, ease: Easing? = .none) -> Kinieta {
        
        let m = Transformation(dict)
        
        stack.append(m)
        
        return self
    }
    
    func snap(_ dict:Properties) -> Kinieta {
        
        let m = Transformation(dict)
        
        self.view.transform = m.cgAffineTransform
        
        return self
    }
    
    func wait(_ time:TimeInterval) -> Kinieta {
        
        
        return self
    }
}

extension UIView {
    
    public var kinieta: Kinieta {
        
        guard let instance = objc_getAssociatedObject(self, &Kinieta.associatedKey) as? Kinieta else {
            let instance = Kinieta(self)
            objc_setAssociatedObject(self, &Kinieta.associatedKey, instance, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return instance
        }
        
        return instance
        
    }
}
