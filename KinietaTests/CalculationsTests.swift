//
//  CalculationsTests.swift
//  Kinieta
//
//  Created by Michael Michailidis on 04/09/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import XCTest
@testable import Kinieta

class CalculationsTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testRotationCalculations() {
        
        let angle:CGFloat = 30.0
        
        let v = UIView()
        v.rotation = angle
        
        let t = CGAffineTransform(rotationAngle: angle.degreesToRadians)
        
        XCTAssert(v.transform.a == t.a, "Value 'a' not calculated correctly")
        XCTAssert(v.transform.b == t.b, "Value 'b' not calculated correctly")
        XCTAssert(v.transform.c == t.c, "Value 'c' not calculated correctly")
        XCTAssert(v.transform.d == t.d, "Value 'd' not calculated correctly")
    }

}
