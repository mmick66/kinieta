//
//  Extensions.swift
//  Kinieta
//
//  Created by Michael Michailidis on 31/08/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import Foundation

class Easing {
    
    // Easing curves are from https://github.com/ai/easings.net/
    
    public static let none:Bezier           = Bezier(0.250, 0.250,  0.750,  0.750) // linear
    public static let liner:Bezier          = none
    
    public static let sineIn:Bezier         = Bezier(0.47,  0,      0.745,  0.715)
    public static let sineOut:Bezier        = Bezier(0.39,  0.575,  0.565,  1.0)
    public static let sineInOut:Bezier      = Bezier(0.455, 0.03,   0.515,  0.955)
    
    public static let quadIn:Bezier         = Bezier(0.55,  0.085,  0.68,   0.53)
    public static let quadOut:Bezier        = Bezier(0.25,  0.46,   0.45,   0.94)
    public static let quadInOut:Bezier      = Bezier(0.455, 0.03,   0.515,  0.955)
    
    public static let cubicIn:Bezier        = Bezier(0.55,  0.055,  0.675,  0.19)
    public static let cubicOut:Bezier       = Bezier(0.215, 0.61,   0.355,  1.0)
    public static let cubicInOut:Bezier     = Bezier(0.645, 0.045,  0.355,  1.0)
    
    // Utility Methods
    public static let easeIn:Bezier        = cubicIn
    public static let easeOut:Bezier       = cubicOut
    public static let easeInOut:Bezier     = cubicInOut
    
    public static let quartIn:Bezier        = Bezier(0.895, 0.03,   0.685,  0.22)
    public static let quartOut:Bezier       = Bezier(0.165, 0.84,   0.44,   1.0)
    public static let quartInOut:Bezier     = Bezier(0.77,  0,      0.175,  1.0)
    
    public static let quintIn:Bezier        = Bezier(0.755, 0.05,   0.855,  0.06)
    public static let quintOut:Bezier       = Bezier(0.23,  1.0,    0.32,   1.0)
    public static let quintInOut:Bezier     = Bezier(0.86,  0,      0.07,   1.0)
    
    public static let expoIn:Bezier         = Bezier(0.95,  0.05,   0.795,  0.035)
    public static let expoOut:Bezier        = Bezier(0.19,  1.0,    0.22,   1.0)
    public static let expoInOut:Bezier      = Bezier(1.0,   0,      0,      1.0)
    
    public static let backIn:Bezier         = Bezier(0.6,  -0.28,   0.735,  0.045)
    public static let backOut:Bezier        = Bezier(0.175, 0.885,  0.32,   1.275)
    public static let backInOut:Bezier      = Bezier(0.68, -0.55,   0.265,  1.55)
    
}
