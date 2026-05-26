import Foundation
import PlainCore
import XCTest

final class URLHandoffParserTests: XCTestCase {
    func testParsesDirectWebURL() {
        let parser = URLHandoffParser()

        XCTAssertEqual(
            parser.sourceURL(from: "https://example.com/read")?.absoluteString,
            "https://example.com/read"
        )
    }

    func testParsesPlainOpenURL() {
        let parser = URLHandoffParser()

        XCTAssertEqual(
            parser.sourceURL(from: "plain://open?url=https%3A%2F%2Fexample.com%2Fread%3Fid%3D42")?.absoluteString,
            "https://example.com/read?id=42"
        )
    }

    func testRejectsNonWebURLs() {
        let parser = URLHandoffParser()

        XCTAssertNil(parser.sourceURL(from: "plain://open?url=file%3A%2F%2F%2Fetc%2Fhosts"))
    }
}
