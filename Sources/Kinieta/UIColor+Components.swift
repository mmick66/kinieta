/*
 * UIColor+Components.swift

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

/* Thanks to Gregor Aisch from https://github.com/gka/chroma.js  */

#if canImport(UIKit)
import UIKit

extension UIColor {

    /// Never usable outside Kinieta: it has no public initialiser or members.
    @available(*, deprecated, message: "Not usable outside Kinieta; removed in Kinieta 2.0.")
    public struct Components: Equatable, CustomStringConvertible {

        var c1: CGFloat, c2: CGFloat, c3: CGFloat, alpha: CGFloat
        public enum Space: String {
            case RGB = "RGB"
            case HSB = "HSB"
            case HCL = "HCL"
        }
        let space: Space
        init(_ c1: CGFloat, _ c2: CGFloat, _ c3: CGFloat, _ alpha: CGFloat, space: Components.Space) {
            self.c1 = c1
            self.c2 = c2
            self.c3 = c3
            self.alpha = alpha
            self.space = space
        }

        public static func == (lhs: Components, rhs: Components) -> Bool {
            guard lhs.space == rhs.space else { return false }
            return (lhs.c1 == rhs.c1) && (lhs.c2 == rhs.c2) && (lhs.c3 == rhs.c3) && (lhs.alpha == rhs.alpha)
        }

        public var description: String {
            return "(c1:\(c1), c2:\(c2), c3:\(c3), alpha:\(alpha), space:\(space.rawValue))"
        }
    }
}
#endif
