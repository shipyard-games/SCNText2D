import XCTest
@testable import SCNText2D

final class SCNText2DTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(SCNText2D().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
