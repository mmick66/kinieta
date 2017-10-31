//
//  ColorComponentsTests.swift
//  KinietaTests
//
//  Created by Michael Michailidis on 19/10/2017.
//  Copyright © 2017 Michael Michailidis. All rights reserved.
//

import XCTest

class ColorComponentsTests: XCTestCase {
    
    let originalColor = UIColor(red:237.0 / 255.0, green: 99.0 / 255.0, blue: 102.0 / 255.0, alpha:1.00)
    
    override func setUp() {
        super.setUp()
        
    }
    
    override func tearDown() {
        
        super.tearDown()
    }
    
    @discardableResult
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
        
        print("Compare:\n\t o-color: \"\(originalColor)\"\n\t d-color: \"\(derivativeColor)\"")
        XCTAssert(originalColor.description == derivativeColor.description, "Colors do not match")
        
    }
    
    
    func testHLCValueExtraction() {
        let (h,l,c,a) = self.originalColor.hlca
        
        XCTAssert((h * LCHColor.MaxH) ~= 25.63104309046355, "Hue (\(h * LCHColor.MaxH)) != 25.63104309046355")
        XCTAssert((l * LCHColor.MaxL) ~= 59.78697847134286, "Luminosity (\(l * LCHColor.MaxL)) != 59.78697847134286")
        XCTAssert((c * LCHColor.MaxC) ~= 59.360754654915006, "Chroma (\(c * LCHColor.MaxC)) != 59.360754654915006")
        XCTAssert(a == 1.0, "Colors do not match")
    }
    
    func testPerformanceExample() {
        
        self.measure {
            self.createDerivativeColor(space: .HLC)
        }
    }
    
}

infix operator ~=
func ~=(lhs:CGFloat, rhs:CGFloat) -> Bool {
    return CGFloat(round(lhs * 10.0) / 10.0) == CGFloat(round(rhs * 10.0) / 10.0)
}
