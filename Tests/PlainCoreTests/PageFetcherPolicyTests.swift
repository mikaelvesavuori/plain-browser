import PlainCore
import XCTest

final class PageFetcherPolicyTests: XCTestCase {
    func testDefaultFetchPolicyMatchesReleaseSafetyEnvelope() {
        let fetcher = PageFetcher()

        XCTAssertEqual(fetcher.maxResponseBytes, 2_000_000)
        XCTAssertEqual(fetcher.maxRedirects, 10)
        XCTAssertEqual(fetcher.timeout, 15)
        XCTAssertEqual(fetcher.userAgent, "Plain/0.1")
        XCTAssertEqual(fetcher.privacyConfiguration.timeout, 15)
    }
}
