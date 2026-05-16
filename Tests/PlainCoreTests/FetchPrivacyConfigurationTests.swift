import Foundation
import PlainCore
import XCTest

final class FetchPrivacyConfigurationTests: XCTestCase {
    func testEphemeralConfigurationDoesNotStoreOrAcceptCookies() {
        let configuration = FetchPrivacyConfiguration(timeout: 15).makeURLSessionConfiguration()

        XCTAssertEqual(configuration.timeoutIntervalForRequest, 15)
        XCTAssertEqual(configuration.timeoutIntervalForResource, 15)
        XCTAssertEqual(configuration.requestCachePolicy, .reloadIgnoringLocalAndRemoteCacheData)
        XCTAssertNil(configuration.urlCache)
        XCTAssertEqual(configuration.httpCookieAcceptPolicy, .never)
        XCTAssertFalse(configuration.httpShouldSetCookies)
        XCTAssertNil(configuration.httpCookieStorage)
        XCTAssertEqual(configuration.httpAdditionalHeaders?["Cache-Control"] as? String, "no-store")
    }
}
