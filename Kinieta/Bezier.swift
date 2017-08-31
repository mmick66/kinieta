//
//  Bezier.swift
//  Kinieta
//
//  Created by Michael Michailidis on 31/08/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import UIKit


struct Bezier {
    
    struct Point {
        
        let x: Double
        let y: Double
        init(_ x: Double, _ y: Double) {
            self.x = x
            self.y = y
        }
        var cgPoint: CGPoint {
            return CGPoint(x: self.x, y: self.y)
        }
        static func *(lhs:Double, rhs:Point) -> Point {
            return Point(lhs * rhs.x, lhs * rhs.y)
        }
        static func +(lhs:Point, rhs:Point) -> Point {
            return Point(lhs.x + rhs.x, lhs.y + rhs.y)
        }
    }
    
    let p0:Point = Point(0.0, 0.0)
    let p1:Point
    let p2:Point
    let p3:Point = Point(1.0, 1.0)
    
    init(_ p1x:Double, _ p1y:Double, _ p2x:Double, _ p2y:Double) {
        p1 = Point(p1x, p1y)
        p2 = Point(p2x, p2y)
    }
    
    func solve(_ t:Double) -> Double {
        
        let omt = 1.0 - t
        let tsq = t * t
        
        let tm1 = (3 * t * omt * omt) * p1
        let tm2 = (3 * tsq * omt) * p2
        let tm3 = (t * tsq) * p3
        
        return (tm1 + tm2 + tm3).y
    }
}

