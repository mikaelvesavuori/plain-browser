import Foundation
import PlainCore
import XCTest

final class URLNormalizerTests: XCTestCase {
    func testNormalizeAddsHTTPSAndStripsTrackingParameters() throws {
        let normalizer = URLNormalizer()

        let url = try normalizer.normalize(
            "Example.com/read?utm_source=newsletter&fbclid=abc&id=42#comments"
        )

        XCTAssertEqual(url.absoluteString, "https://example.com/read?id=42")
    }

    func testNormalizeTurnsSearchTextIntoMojeekQuery() throws {
        let normalizer = URLNormalizer()

        let url = try normalizer.normalize("plain browser")

        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host(), "www.mojeek.com")
        XCTAssertEqual(url.path(), "/search")
        XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems, [
            URLQueryItem(name: "q", value: "plain browser")
        ])
    }

    func testNormalizeTurnsBareWordsIntoMojeekQuery() throws {
        let normalizer = URLNormalizer()

        let url = try normalizer.normalize("plain")

        XCTAssertEqual(url.absoluteString, "https://www.mojeek.com/search?q=plain")
    }

    func testNormalizeKeepsDomainLikeInputsAsURLs() throws {
        let normalizer = URLNormalizer()

        let url = try normalizer.normalize("www.mojeek.com/search?q=plain")

        XCTAssertEqual(url.absoluteString, "https://www.mojeek.com/search?q=plain")
    }

    func testNormalizeRejectsUnsupportedSchemes() throws {
        let normalizer = URLNormalizer()

        XCTAssertThrowsError(try normalizer.normalize("javascript:alert(1)")) { error in
            XCTAssertEqual(error as? PlainError, .unsupportedScheme("javascript"))
        }
    }

    func testNormalizeBlocksLocalTargets() {
        let normalizer = URLNormalizer()

        XCTAssertThrowsError(try normalizer.normalize("http://localhost:8080/read"))
    }

    func testNormalizeKeepsRelativeURLsWhenBaseURLIsProvided() throws {
        let normalizer = URLNormalizer()
        let url = try normalizer.normalize("/next", baseURL: URL(string: "https://example.com/read")!)

        XCTAssertEqual(url.absoluteString, "https://example.com/next")
    }
}
