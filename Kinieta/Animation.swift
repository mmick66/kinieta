//
//  Kinieta.swift
//  Kinieta
//
//  Created by Michael Michailidis on 31/08/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit


class Animation: Action {
    
    private var transformations:[TransformationBlock] = []
    
    private(set) var easing: Bezier
    
    private(set) var duration: TimeInterval
    private(set) var currentt: TimeInterval = 0.0
    
    var complete: Block?
    
    var initial: [String: Any]?
    
    init(_ view: UIView, moves: [String: Any], duration: TimeInterval, easing: Bezier?, complete: (()->Void)?) {
        
        self.duration   = duration
        self.easing     = easing ?? Easing.Linear
        self.complete   = complete
        
        for (property, value) in abbriviate(moves) {
            let transformation = transormation(in: view, for: property, with: value)
            transformations.append(transformation)
        }
    }
    
    private func abbriviate(_ properties: [String: Any]) -> [String: Any] {
        var p = properties
        if let width = p.pop("width")           { p["w"] = width }
        if let height = p.pop("height")         { p["h"] = height }
        if let color = p.pop("background")      { p["bg"] = color }
        if let color = p.pop("borderColor")     { p["brc"] = color }
        if let width = p.pop("borderWidth")     { p["brw"] = width }
        if let radius = p.pop("cornerRadius")   { p["crd"] = radius }
        return p
    }
    
    static let FrameProperties = ["x", "y", "w", "h", "width", "height"]
    private func pack(_ properties: [String: Any], for view: UIView) -> [String: Any] {
        var p = properties
        guard p.intersection(Animation.FrameProperties) else { return p }
        let x = CGFloat.parse(p.pop("x")) ?? view.x
        let y = CGFloat.parse(p.pop("y")) ?? view.y
        let w = CGFloat.parse(p.pop("w")) ?? CGFloat.parse(p.pop("width"))  ?? view.width
        let h = CGFloat.parse(p.pop("h")) ?? CGFloat.parse(p.pop("height")) ?? view.height
        p["frame"] = CGRect(x: x, y: y, width: w, height: h)
        return p
    
    }
    
    func update(_ frame: Engine.Frame) -> ActionResult {
        
        guard duration > 0.0 else {
            for transformation in transformations {
                transformation(1.0)
            }
            return .Finished
        }
        
        currentt += frame.duration
        currentt  = currentt > duration ? duration : currentt
        
        let tpoint = currentt / duration
        let ypoint = self.easing.solve(tpoint)
        for transformation in transformations {
            transformation(ypoint)
        }
        
        if tpoint == 1.0 { // reached end
            self.complete?()
            return .Finished
        }
        
        return .Running
        
    }
    
    static func interpolation<T: CGFractionable>(from start:T, to end:T, block: @escaping (T) -> Void) -> TransformationBlock {
        return { factor in
            let cgFactor = CGFloat(factor)
            let iValue = (1.0 - cgFactor) * start + cgFactor * end
            block(iValue)
        }
    }
    
    typealias TransformationBlock = (Double) -> Void
    func transormation(in view: UIView, for property:String, with value:Any) -> TransformationBlock {
        
        let cgValue = CGFloat.parse(value) ?? 1.0
        
        switch property {
            
        case "x":
            return Animation.interpolation(from: view.x, to: cgValue) { view.x = $0 }
            
        case "y":
            return Animation.interpolation(from: view.y, to: cgValue) { view.y = $0 }
            
        case "w", "width":
            return Animation.interpolation(from: view.width, to: cgValue) { view.width = $0 }
            
        case "h", "height":
            return Animation.interpolation(from: view.height, to: cgValue) { view.height = $0 }
            
        case "r", "rotation":
            return Animation.interpolation(from: view.rotation, to: cgValue) { view.rotation = $0 }
            
        case "a", "alpha":
            return Animation.interpolation(from: view.alpha, to: cgValue) { view.alpha = $0 }
            
        case "frame":
            return Animation.interpolation(from: view.frame, to: value as! CGRect) { view.frame = $0 }
  
        case "bg", "background":
            guard let valueAsColor = value as? UIColor else { fatalError("The \"\(property)\" key needs to be of UIColor type") }
            
            let fComponents     = view.backgroundColorOrClear.components(for: .HSB)
            let tComponents     = valueAsColor.components(for: .HSB)
            
            return Animation.interpolation(from: fComponents, to: tComponents) { iComponents in
                view.backgroundColor = UIColor(components: iComponents)
            }
            
        case "brc", "borderColor":
            guard let valueAsColor = value as? UIColor else { fatalError("The \"\(property)\" key needs to be of UIColor type") }
            
            let fComponents     = view.borderColorOrClear.components(for: .HSB)
            let tComponents     = valueAsColor.components(for: .HSB)
            
            return Animation.interpolation(from: fComponents, to: tComponents) { iComponents in
                view.layer.borderColor = UIColor(components: iComponents).cgColor
            }
            
        case "brw", "borderWidth":
            return Animation.interpolation(from: view.layer.borderWidth, to: cgValue) { view.layer.borderWidth = $0 }
            
        case "crd", "cornerRadius":
            return Animation.interpolation(from: view.layer.borderWidth, to: cgValue) { view.layer.borderWidth = $0 }
            
        default:
            return { _ in }
        }
        
    }
    
}



