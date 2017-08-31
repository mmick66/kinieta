//
//  Extensions.swift
//  Kinieta
//
//  Created by Michael Michailidis on 31/08/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import Foundation

extension Bezier {
    
    // Easing curves are from https://github.com/ai/easings.net/
    public static let easeInSine:Bezier     = Bezier(0.47,0,0.745,0.715)
    public static let easeOutSine:Bezier    = Bezier(0.39,0.575,0.565, 1)
    public static let easeInOutSine:Bezier  = Bezier(0.455,0.03,0.515,0.955)
    public static let easeInQuad:Bezier     = Bezier(0.55, 0.085, 0.68, 0.53)
    public static let easeOutQuad:Bezier    = Bezier(0.25, 0.46, 0.45, 0.94)
    public static let easeInOutQuad:Bezier  = Bezier(0.455, 0.03, 0.515, 0.955)
    public static let easeInCubic:Bezier    = Bezier(0.55, 0.055, 0.675, 0.19)
    public static let easeOutCubic:Bezier   = Bezier(0.215, 0.61, 0.355, 1)
    public static let easeInOutCubic:Bezier = Bezier(0.645, 0.045, 0.355, 1)
    public static let easeInQuart:Bezier    = Bezier(0.895, 0.03, 0.685, 0.22)
    public static let easeOutQuart:Bezier   = Bezier(0.165, 0.84, 0.44, 1)
    public static let easeInOutQuart:Bezier = Bezier(0.77, 0, 0.175, 1)
    public static let easeInQuint:Bezier    = Bezier(0.755, 0.05, 0.855, 0.06)
    public static let easeOutQuint:Bezier   = Bezier(0.23, 1, 0.32, 1)
    public static let easeInOutQuint:Bezier = Bezier(0.86,0,0.07,1)
    public static let easeInExpo:Bezier     = Bezier(0.95, 0.05, 0.795, 0.035)
    public static let easeOutExpo:Bezier    = Bezier(0.19, 1, 0.22, 1)
    public static let easeInOutExpo:Bezier  = Bezier(1, 0, 0, 1)
    public static let easeInCirc:Bezier     = Bezier(0.6, 0.04, 0.98, 0.335)
    public static let easeOutCirc:Bezier    = Bezier(0.075, 0.82, 0.165, 1)
    public static let easeInOutCirc:Bezier  = Bezier(0.785, 0.135, 0.15, 0.86)
    public static let easeInBack:Bezier     = Bezier(0.6, -0.28, 0.735, 0.045)
    public static let easeOutBack:Bezier    = Bezier(0.175, 0.885, 0.32, 1.275)
    public static let easeInOutBack:Bezier  = Bezier(0.68, -0.55, 0.265, 1.55)
    
}
