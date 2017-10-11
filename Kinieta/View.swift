//
//  Extensions.swift
//  Kinieta
//
//  Created by Michael Michailidis on 06/09/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

extension UIView {
    @discardableResult
    func move(_ dict: [String:Any], during duration: TimeInterval = 0.0) -> Kinieta {
        let kinieta = Kinieta(for: self)
        kinieta.move(dict, during: duration)
        Engine.shared.add(kinieta)
        return kinieta
    }
    @discardableResult
    func wait(time: TimeInterval) -> Kinieta {
        let kinieta = Kinieta(for: self)
        kinieta.wait(for: time)
        Engine.shared.add(kinieta)
        return kinieta
    }
}

extension UIView {
    var rotation:CGFloat {
        get {
            return atan2(self.transform.b, self.transform.a).radiansToDegrees
        }
        set {
            let rads = newValue.degreesToRadians
            var tr_p = self.transform
            tr_p.a =  cos(rads)
            tr_p.b =  sin(rads)
            tr_p.c = -sin(rads)
            tr_p.d =  cos(rads)
            self.transform = tr_p

        }
    }
}

func >>(lhs: Range<TimeInterval>, rhs: TimeInterval) -> Range<TimeInterval> {
    return (lhs.lowerBound+rhs)..<(lhs.upperBound+rhs)
}

extension UIView {
    var properties: [String: Any] {
        get {
            var dict = [String: Any]()
            
            dict["x"] = self.frame.origin.x
            dict["y"] = self.frame.origin.y
            dict["w"] = self.frame.size.width
            dict["h"] = self.frame.size.height
            dict["r"] = self.rotation
            dict["a"] = self.alpha
            
            if let bg = self.backgroundColor {
                dict["bg"] = bg
            }
            
            if let brc = self.layer.borderColor {
                dict["brc"] = UIColor(cgColor: brc)
            }
            dict["brw"] = self.layer.borderWidth
            dict["crd"] = self.layer.cornerRadius
            
            return dict
        }
    }
}

