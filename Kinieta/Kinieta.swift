//
//  Kinieta.swift
//  Kinieta
//
//  Created by Michael Michailidis on 31/08/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit


typealias TransformationBlock = (Double) -> Void

class Kinieta {
    
    private(set) var view:UIView
    private var transformations:[TransformationBlock] = []
    private var timeframe: Range<TimeInterval> = 0.0..<0.0
    
    init(_ view:UIView) {
        self.view = view
        Engine.shared.add(self)
    }
    
    // MARK: API
    func move(_ dict: [String:Any], _ duration: TimeInterval) -> Kinieta {
        
        let ctime = CACurrentMediaTime()
        
        timeframe = ctime..<(ctime+duration)
        
        for (key,value) in dict {
            let transformation = createTransormation(of: key, for: value)
            transformations.append(transformation)
        }
        
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
    
    private(set) var onComplete: () -> Void = { _ in }
    func complete(_ block: () -> Void) {
        self.oncomplete = block
    }
    
    // MARK: Update
    @discardableResult func update(_ frame: Engine.Frame) -> Bool {
        
        guard timeframe.contains(frame.timestamp) else {
            return true
        }
        
        
        let factor = (frame.timestamp - timeframe.lowerBound) / (timeframe.upperBound - timeframe.lowerBound)
        
        for transformation in transformations {
            transformation(factor)
        }
        
        return false
    }
    
    
    // MARK: Create Transformations
    internal func createTransormation(of property:String, for value:Any) -> TransformationBlock {
        
        let cgFloatValue: CGFloat = (value as? CGFloat) ?? 1.0
        
        switch property {
            
        case "x":
            return createFloatInterpolation(from: self.view.center.x, to: cgFloatValue) { nValue in
                self.view.center = CGPoint(x: nValue, y: self.view.center.y)
            }
            
        case "y":
            return createFloatInterpolation(from: self.view.center.x, to: cgFloatValue) { nValue in
                self.view.center = CGPoint(x: self.view.center.x, y: nValue)
            }
            
        case "w", "width":
            return createFloatInterpolation(from: self.view.frame.size.width, to: cgFloatValue) { nValue in
                var oFrame = self.view.frame
                oFrame.size.width = nValue
                self.view.frame = oFrame
            }
            
        case "h", "height":
            return createFloatInterpolation(from: self.view.frame.size.height, to: cgFloatValue) { nValue in
                var oFrame = self.view.frame
                oFrame.size.height = nValue
                self.view.frame = oFrame
            }
            
        case "r", "rotation":
            return createFloatInterpolation(from: self.view.rotation, to: cgFloatValue) { nValue in
                self.view.rotation = nValue
            }
            
        case "a", "alpha":
            return createFloatInterpolation(from: self.view.alpha, to: cgFloatValue) { nValue in
                self.view.alpha = nValue
            }
            
        case "bg", "background":
            return createColorInterpolation(from: self.view.backgroundColor ?? UIColor.white, to: value as! UIColor) { nColor in
                self.view.backgroundColor = nColor
            }
            
        case "brc", "borderColor":
            return createColorInterpolation(from: self.view.backgroundColor ?? UIColor.white, to: value as! UIColor) { nColor in
                self.view.layer.borderColor = nColor.cgColor
            }
            
        case "brw", "borderWidth":
            return createFloatInterpolation(from: self.view.layer.borderWidth, to: cgFloatValue) { nValue in
                self.view.layer.borderWidth = nValue
            }
            
        default:
            return { _ in }
        }
        
    }
}



