@testable import PlainCore
import XCTest

final class ReleaseUpdateCheckerTests: XCTestCase {
    func testVersionComparisonHandlesCommonReleaseTags() {
        XCTAssertGreaterThan(try XCTUnwrap(PlainVersion("v1.1.0")), try XCTUnwrap(PlainVersion("1.0.0")))
        XCTAssertGreaterThan(try XCTUnwrap(PlainVersion("1.10.0")), try XCTUnwrap(PlainVersion("1.2.0")))
        XCTAssertEqual(try XCTUnwrap(PlainVersion("v1.0")), try XCTUnwrap(PlainVersion("1.0.0")))
        XCTAssertEqual(try XCTUnwrap(PlainVersion("1")), try XCTUnwrap(PlainVersion("1.0.0")))
    }

    func testVersionParsingRejectsDevelopmentAndPrereleaseLikeValues() {
        XCTAssertNil(PlainVersion("development"))
        XCTAssertNil(PlainVersion("1.0.0-alpha"))
        XCTAssertNil(PlainVersion(""))
    }
}
