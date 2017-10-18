/*
 * Bezier.swift
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


struct Bezier {
    
    static var Accuracy = 1000
    static let Factors  = Table(with: Bezier.Accuracy)
    
    struct Table {
        let C0:[Double]
        let C1:[Double]
        let C2:[Double]
        let C3:[Double]
        init(with steps: Int) {
            var _C0 = [Double](repeating: 0.0, count: steps+1)
            var _C1 = [Double](repeating: 0.0, count: steps+1)
            var _C2 = [Double](repeating: 0.0, count: steps+1)
            var _C3 = [Double](repeating: 0.0, count: steps+1)
            for step in 0...steps {
                let T = Double(step)/Double(steps);
                _C0[step] = (1.0 - T) * (1.0 - T) * (1.0 - T);
                _C1[step] = 3.0 * (1.0 - T) * (1.0 - T) * T;
                _C2[step] = 3.0 * (1.0 - T) * T * T;
                _C3[step] = T * T * T;
            }
            C0 = _C0
            C1 = _C1
            C2 = _C2
            C3 = _C3
        }
    }
    
    struct Point: CustomStringConvertible {
        
        let x: Double
        let y: Double
        init(_ x: Double = 0.0, _ y: Double = 0.0) {
            self.x = x
            self.y = y
        }
        var cgPoint: CGPoint {
            return CGPoint(x: self.x, y: self.y)
        }
        static func *(lhs:Point, rhs:Double) -> Point {
            return Point(lhs.x * rhs, lhs.y * rhs)
        }
        static func *(lhs:Double, rhs:Point) -> Point {
            return Point(lhs * rhs.x, lhs * rhs.y)
        }
        static func +(lhs:Point, rhs:Point) -> Point {
            return Point(lhs.x + rhs.x, lhs.y + rhs.y)
        }
        var description: String {
            return "(x:\(self.x), y:\(self.y))"
        }
    }
    
    let P0:Point = Point(0.0, 0.0)
    let P1:Point
    let P2:Point
    let P3:Point = Point(1.0, 1.0)
    
    let POINTS:[Point]
    init(_ p1x:Double, _ p1y:Double, _ p2x:Double, _ p2y:Double) {
        P1 = Point(p1x, p1y)
        P2 = Point(p2x, p2y)
        let F = Bezier.Factors
        var _P = [Point](repeating: Point(), count: Bezier.Accuracy+1)
        for step in 0...Bezier.Accuracy {
            _P[step] = F.C0[step] * P0 + F.C1[step] * P1 + F.C2[step] * P2 + F.C3[step] * P3
        }
        POINTS = _P
    }
    
    
    func solve(_ t:Double) -> Double {
        let T = Int(t * Double(Bezier.Accuracy))
        return POINTS[T].y
    }
}

