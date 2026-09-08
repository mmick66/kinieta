// Kinieta — MIT License. See LICENSE.

import Foundation

/// A cubic Bézier easing curve from (0, 0) to (1, 1), defined by its two inner
/// control points, exactly as CSS `cubic-bezier()` and cubic-bezier.com do.
///
/// The curve is baked into a lookup table once at creation, so solving is a
/// binary search rather than root finding.
public struct Bezier: Sendable, Equatable {

    static let accuracy = 1000
    static let factors = Table(steps: Bezier.accuracy)

    /// Identity: progress equals time.
    public static let linear = Bezier(0.25, 0.25, 0.75, 0.75)

    struct Table: Sendable {
        let c0: [Double], c1: [Double], c2: [Double], c3: [Double]
        init(steps: Int) {
            var c0 = [Double](repeating: 0, count: steps + 1)
            var c1 = c0, c2 = c0, c3 = c0
            for step in 0...steps {
                let t = Double(step) / Double(steps)
                c0[step] = (1 - t) * (1 - t) * (1 - t)
                c1[step] = 3 * (1 - t) * (1 - t) * t
                c2[step] = 3 * (1 - t) * t * t
                c3[step] = t * t * t
            }
            self.c0 = c0; self.c1 = c1; self.c2 = c2; self.c3 = c3
        }
    }

    public struct Point: Sendable, Equatable, CustomStringConvertible {
        public let x: Double
        public let y: Double
        public init(_ x: Double = 0, _ y: Double = 0) {
            self.x = x
            self.y = y
        }
        static func * (lhs: Double, rhs: Point) -> Point { Point(lhs * rhs.x, lhs * rhs.y) }
        static func + (lhs: Point, rhs: Point) -> Point { Point(lhs.x + rhs.x, lhs.y + rhs.y) }
        public var description: String { "(x: \(x), y: \(y))" }
    }

    public let p0 = Point(0, 0)
    public let p1: Point
    public let p2: Point
    public let p3 = Point(1, 1)

    let points: [Point]

    /// Creates a curve from the two inner control points, in the order
    /// cubic-bezier.com lists them: `Bezier(p1x, p1y, p2x, p2y)`.
    public init(_ p1x: Double, _ p1y: Double, _ p2x: Double, _ p2y: Double) {
        p1 = Point(p1x, p1y)
        p2 = Point(p2x, p2y)
        let f = Bezier.factors
        var baked = [Point](repeating: Point(), count: Bezier.accuracy + 1)
        for step in 0...Bezier.accuracy {
            baked[step] = f.c0[step] * p0 + f.c1[step] * p1 + f.c2[step] * p2 + f.c3[step] * p3
        }
        points = baked
    }

    public static func == (lhs: Bezier, rhs: Bezier) -> Bool {
        lhs.p1 == rhs.p1 && lhs.p2 == rhs.p2
    }

    /// Returns the eased progress for a time fraction `x` in 0...1.
    ///
    /// `x` is time and `y` is progress. The baked table is searched on `x` and
    /// `y` is interpolated linearly between the two nearest samples, so `y` can
    /// leave 0...1 for curves such as `backInOut`. Time outside 0...1 is clamped.
    public func solve(_ x: Double) -> Double {
        if x <= 0 { return 0 }
        if x >= 1 { return 1 }
        var low = 0
        var high = Bezier.accuracy
        while high - low > 1 {
            let mid = (low + high) / 2
            if points[mid].x <= x { low = mid } else { high = mid }
        }
        let a = points[low], b = points[high]
        let span = b.x - a.x
        guard span > 0 else { return a.y }
        return a.y + (b.y - a.y) * (x - a.x) / span
    }
}
