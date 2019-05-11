//
//  SCNText2D_macOSTests.swift
//  SCNText2D-macOSTests
//
//  Created by Teemu Harju on 10/02/2019.
//

import XCTest
@testable import SCNText2D

class SCNText2D_macOSTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        SCNText2D.load(font: "OpenSans-Regular", bundle: Bundle(for: SCNText2D_macOSTests.self))
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let geometry = SCNText2D.create(from: "test test test", withFontNamed: "OpenSans-Regular")
        
        XCTAssert(geometry.elementCount == 1)
    }
    
    func testPerformanceLoadFont() {
        self.measure {
            SCNText2D.load(font: "OpenSans-Regular", bundle: Bundle(for: SCNText2D_macOSTests.self))
        }
    }

    func testPerformanceCreateGeometry() {
        
        let text =
        """
        It is a period of civil war.
        Rebel spaceships, striking
        from a hidden base, have won
        their first victory against
        the evil Galactic Empire.

        During the battle, Rebel
        spies managed to steal secret
        plans to the Empire's
        ultimate weapon, the DEATH
        STAR, an armored space
        station with enough power to
        destroy an entire planet.

        Pursued by the Empire's
        sinister agents, Princess
        Leia races home aboard her
        starship, custodian of the
        stolen plans that can save
        her people and restore
        freedom to the galaxy.....
        """
        
        self.measure {
            let _ = SCNText2D.create(from: text, withFontNamed: "OpenSans-Regular")
        }
    }
}
