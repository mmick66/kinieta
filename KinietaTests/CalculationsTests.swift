//
//  CalculationsTests.swift
//  Kinieta
//
//  Created by Michael Michailidis on 04/09/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import XCTest

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
    
    func testLABcol2ColorConvertion() {
        let col1 = UIColor(red:1.00, green:0.44, blue:0.75, alpha:1.00)
        let data = col1.laba()
        let comp = UIColor.Components(data, space: .LAB)
        let col2 = UIColor(components: comp)
        
        XCTAssert(col1 == col2, "Colors do not match")
        
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
