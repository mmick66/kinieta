//
//  ColorComponentsTests.swift
//  KinietaTests
//
//  Created by Michael Michailidis on 19/10/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import XCTest

class ColorComponentsTests: XCTestCase {
    
    let originalColor = UIColor(red:1.00, green:0.44, blue:0.75, alpha:1.00)
    
    override func setUp() {
        super.setUp()
        
    }
    
    override func tearDown() {
        
        super.tearDown()
    }
    
    func createDerivativeColor(space: UIColor.Components.Space) -> UIColor {
        let data = originalColor.components(as: space)
        return UIColor(components: data)
    }
    
    func testRGBColorConvertion() {
        
        let derivativeColor = self.createDerivativeColor(space: .RGB)
        
        XCTAssert(originalColor == derivativeColor, "Colors do not match")
        
    }
    
    func testHSBColorConvertion() {
        
        let derivativeColor = self.createDerivativeColor(space: .HSB)
        
        // print("Compare:\n\to-comps:\(originalComponents)\n\td-comps:\(derivativeColor.components(as: .HSB))")
        print("Compare:\n\t o-color:\(originalColor)\n\t d-color:\(derivativeColor)")
        XCTAssert(originalColor == derivativeColor, "Colors do not match")
        
    }
    
    func testLABColorConvertion() {
        
        let derivativeColor = self.createDerivativeColor(space: .LAB)
        
        XCTAssert(originalColor == derivativeColor, "Colors do not match")
        
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
