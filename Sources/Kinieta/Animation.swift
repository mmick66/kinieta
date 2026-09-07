/*
 * Animation.swift
 * Created by Michael Michailidis on 16/10/2017.
 * http://blog.karmadust.com/
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */
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
        for (long,short) in ["width":"w", "height":"h", "background":"bg", "borderColor":"brc", "borderWidth":"brw", "cornerRadius":"crd"] {
            if p[long] != nil { p[short] = p[long] }
            p.removeValue(forKey: long)
        }
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
        
        for block in transformations { block(CGFloat(ypoint)) }
        
        if tpoint == 1.0 { // reached end
            self.complete?()
            return .Finished
        }
        
        return .Running
        
    }
    
    typealias TransformationBlock = (CGFloat) -> Void
    static func interpolation<T: CGFractionable>(from startValue:T, to endValue:T, block: @escaping (T) -> Void) -> TransformationBlock {
        return { factor in
            let interValue = (1.0 - factor) * startValue + factor * endValue
            block(interValue)
        }
    }
    
    internal func clip<T: Comparable>(_ v: T, _ minimum: T, _ maximum: T) -> T {
        return max(min(v, maximum), minimum)
    }
    
    
    func transormation(in view: UIView, for property:String, with value:Any) -> TransformationBlock {
        
        let cgValue:CGFloat = CGFloat.parse(value) ?? 1.0
        
        
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
            guard let valueAsUIColor = value as? UIColor else { fatalError("The \"\(property)\" key needs to be of UIColor type") }
            
            switch Defaults.ColorInterpolation.Method {
                
            case .Pure(let space):
                
                return Animation.interpolation(
                    from: view.backgroundColorOrClear.components(as: space),
                    to: valueAsUIColor.components(as: space),
                    block: { iComps in view.backgroundColor = UIColor(components: iComps) })
            
            case .RGB_HLC_Assisted:
                
                let spectrum = view.backgroundColorOrClear.spectrumComponentsHLC5(to: valueAsUIColor)
                
                return { factor in
                    var iComps: UIColor.Components
                    switch factor {
                    case 0.00 ... 0.25:
                        let nf = factor / 0.25
                        iComps = (1.0 - nf) * spectrum[0].components(as: .RGB) + nf * spectrum[1].components(as: .RGB)
                    case 0.25 ... 0.50:
                        let nf = (factor - 0.25) / 0.25
                        iComps = (1.0 - nf) * spectrum[1].components(as: .RGB) + nf * spectrum[2].components(as: .RGB)
                    case 0.50 ... 0.75:
                        let nf = (factor - 0.50) / 0.25
                        iComps = (1.0 - nf) * spectrum[2].components(as: .RGB) + nf * spectrum[3].components(as: .RGB)
                    case 0.75 ... 1.00:
                        let nf = (factor - 0.75) / 0.25
                        iComps = (1.0 - nf) * spectrum[3].components(as: .RGB) + nf * spectrum[4].components(as: .RGB)
                    default:
                        fatalError("")
                    }
                    
                    view.backgroundColor = UIColor(components: iComps)
                }
            }
            
            
        case "brc", "borderColor":
            guard let valueAsColor = value as? UIColor else { fatalError("The \"\(property)\" key needs to be of UIColor type") }
            
            let fComponents     = view.borderColorOrClear.components(as: .RGB)
            let tComponents     = valueAsColor.components(as: .RGB)
            
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

extension ClosedRange where Bound == CGFloat {
    func normalize(_ value: CGFloat) -> CGFloat {
        return (value - self.lowerBound) / (self.upperBound - self.lowerBound)
    }
}
