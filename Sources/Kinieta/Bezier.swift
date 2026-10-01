// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit) || os(macOS)
import Foundation

/// A cubic Bézier easing curve from (0, 0) to (1, 1), defined by its two inner
/// control points, exactly as CSS `cubic-bezier()` and cubic-bezier.com do.
///
/// The curve is baked into a lookup table once at creation, so
/// ``progress(at:)`` is a binary search rather than root finding. Copies share the table, and the
/// preset easings are baked once and reused.
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

    /// A control point of the curve: `x` is time and `y` is progress.
    public struct Point: Sendable, Equatable, CustomStringConvertible {
        /// The time coordinate.
        public let x: Double
        /// The progress coordinate.
        public let y: Double

        /// Creates a point at time `x` and progress `y`.
        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }

        /// Creates a point at (`x`, `y`), the origin by default.
        @available(*, deprecated, renamed: "init(x:y:)", message: "Removed in Kinieta 2.0.")
        public init(_ x: Double = 0, _ y: Double = 0) {
            self.init(x: x, y: y)
        }

        static let zero = Point(x: 0, y: 0)
        static func * (lhs: Double, rhs: Point) -> Point { Point(x: lhs * rhs.x, y: lhs * rhs.y) }
        static func + (lhs: Point, rhs: Point) -> Point { Point(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
        /// The point as `(x: 0.25, y: 0.1)`.
        public var description: String { "(x: \(x), y: \(y))" }
    }

    /// The start point, always (0, 0).
    public let p0 = Point(x: 0, y: 0)
    /// The first inner control point, which shapes the start of the curve.
    public let p1: Point
    /// The second inner control point, which shapes the end of the curve.
    public let p2: Point
    /// The end point, always (1, 1).
    public let p3 = Point(x: 1, y: 1)

    let points: [Point]

    /// Creates a curve from the two inner control points, in the order
    /// cubic-bezier.com lists them: `Bezier(p1x, p1y, p2x, p2y)`.
    ///
    /// As in CSS, `p1x` and `p2x` are clamped to 0...1 so that time stays
    /// monotonic. The y values may leave that range to overshoot.
    public init(_ p1x: Double, _ p1y: Double, _ p2x: Double, _ p2y: Double) {
        p1 = Point(x: min(max(p1x, 0), 1), y: p1y)
        p2 = Point(x: min(max(p2x, 0), 1), y: p2y)
        let f = Bezier.factors
        var baked = [Point](repeating: .zero, count: Bezier.accuracy + 1)
        for step in 0...Bezier.accuracy {
            baked[step] = f.c0[step] * p0 + f.c1[step] * p1 + f.c2[step] * p2 + f.c3[step] * p3
        }
        points = baked
    }

    /// Whether two curves have the same inner control points, after clamping.
    public static func == (lhs: Bezier, rhs: Bezier) -> Bool {
        lhs.p1 == rhs.p1 && lhs.p2 == rhs.p2
    }

    /// Returns the eased progress at a time fraction `x` in 0...1.
    ///
    /// `x` is time and `y` is progress. The baked table is searched on `x` and
    /// `y` is interpolated linearly between the two nearest samples, so `y` can
    /// leave 0...1 for curves such as `backInOut`. Time outside 0...1 is clamped.
    ///
    /// ```swift
    /// let snap = Bezier(0.16, 0.73, 0.89, 0.24)
    /// let y = snap.progress(at: 0.3)
    /// ```
    public func progress(at x: Double) -> Double {
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

    @available(*, deprecated, renamed: "progress(at:)", message: "Removed in Kinieta 2.0.")
    public func solve(_ x: Double) -> Double {
        progress(at: x)
    }
}
#endif
