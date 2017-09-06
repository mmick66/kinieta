//
//  Extensions.swift
//  Kinieta
//
//  Created by Michael Michailidis on 06/09/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit

extension UIView {
    func move(_ dict: [String:Any], _ duration: TimeInterval = 0.0) -> Kinieta {
        return Kinieta(self).move(dict, duration)
    }
}

extension UIView {
    var rotation:CGFloat {
        get {
            return atan2(self.transform.b, self.transform.a);
        }
        set {
            let rads = radians(newValue)
            var tr_p = self.transform
            tr_p.a =  cos(rads)
            tr_p.b =  sin(rads)
            tr_p.c = -sin(rads)
            tr_p.d =  cos(rads)
            self.transform = tr_p
        }
    }
}


