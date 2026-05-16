import Foundation
import PlainCore
import XCTest

final class PageFetcherRedirectTests: XCTestCase {
    override func tearDown() {
        RedirectTestURLProtocol.reset()
        super.tearDown()
    }

    func testFetcherFollowsRedirectsAndPreservesRequestPolicy() async throws {
        let startURL = URL(string: "https://redirect.test/start")!
        let finalURL = URL(string: "https://redirect.test/article")!

        RedirectTestURLProtocol.setRoutes([
            startURL.absoluteString: .redirect(location: "/article"),
            finalURL.absoluteString: .html(
                """
                <!doctype html>
                <html>
                  <head><title>Redirect landed</title></head>
                  <body><article><p>The final redirected document arrived.</p></article></body>
                </html>
                """
            )
        ])

        let document = try await makeFetcher().fetch(startURL)

        XCTAssertEqual(document.url, startURL)
        XCTAssertEqual(document.finalURL, finalURL)
        XCTAssertTrue(document.html.contains("The final redirected document arrived."))

        let requests = RedirectTestURLProtocol.recordedRequests()
        XCTAssertEqual(requests.map { $0.url?.absoluteString }, [startURL.absoluteString, finalURL.absoluteString])

        let finalRequest = try XCTUnwrap(requests.last)
        XCTAssertEqual(finalRequest.value(forHTTPHeaderField: "User-Agent"), "PlainTests/1.0")
        XCTAssertEqual(
            finalRequest.value(forHTTPHeaderField: "Accept"),
            "text/html,application/xhtml+xml;q=0.9,*/*;q=0.1"
        )
        XCTAssertEqual(finalRequest.value(forHTTPHeaderField: "Cache-Control"), "no-store")
        XCTAssertEqual(finalRequest.value(forHTTPHeaderField: "Pragma"), "no-cache")
        XCTAssertNil(finalRequest.value(forHTTPHeaderField: "Cookie"))
        XCTAssertNil(finalRequest.value(forHTTPHeaderField: "Referer"))
        XCTAssertNil(finalRequest.value(forHTTPHeaderField: "Origin"))
    }

    func testFetcherBlocksUnsafeRedirectTargetsBeforeFetchingThem() async throws {
        let startURL = URL(string: "https://redirect.test/private-hop")!

        RedirectTestURLProtocol.setRoutes([
            startURL.absoluteString: .redirect(location: "http://127.0.0.1/private")
        ])

        do {
            _ = try await makeFetcher().fetch(startURL)
            XCTFail("Expected the private redirect target to be blocked.")
        } catch PlainError.blockedTargetURL(let reason) {
            XCTAssertTrue(reason.contains("redirected"))
            XCTAssertTrue(reason.contains("Local and private network addresses"))
        }

        let requests = RedirectTestURLProtocol.recordedRequests()
        XCTAssertEqual(requests.map { $0.url?.absoluteString }, [startURL.absoluteString])
    }

    func testFetcherStopsRedirectLoops() async throws {
        let firstURL = URL(string: "https://redirect.test/one")!
        let secondURL = URL(string: "https://redirect.test/two")!
        let thirdURL = URL(string: "https://redirect.test/three")!

        RedirectTestURLProtocol.setRoutes([
            firstURL.absoluteString: .redirect(location: secondURL.absoluteString),
            secondURL.absoluteString: .redirect(location: thirdURL.absoluteString),
            thirdURL.absoluteString: .html("<html><body><article><p>Too late.</p></article></body></html>")
        ])

        do {
            _ = try await makeFetcher(maxRedirects: 1).fetch(firstURL)
            XCTFail("Expected the redirect limit to stop the fetch.")
        } catch PlainError.tooManyRedirects(let limit) {
            XCTAssertEqual(limit, 1)
        }

        let requests = RedirectTestURLProtocol.recordedRequests()
        XCTAssertEqual(requests.map { $0.url?.absoluteString }, [firstURL.absoluteString, secondURL.absoluteString])
    }

    private func makeFetcher(maxRedirects: Int = 10) -> PageFetcher {
        PageFetcher(
            maxRedirects: maxRedirects,
            timeout: 5,
            userAgent: "PlainTests/1.0",
            addressValidator: .staticOnly,
            sessionConfigurationFactory: { privacyConfiguration in
                let configuration = privacyConfiguration.makeURLSessionConfiguration()
                configuration.protocolClasses = [RedirectTestURLProtocol.self]
                return configuration
            }
        )
    }
}

private final class RedirectTestURLProtocol: URLProtocol {
    enum Route {
        case redirect(location: String)
        case html(String)
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var routes: [String: Route] = [:]
    nonisolated(unsafe) private static var requests: [URLRequest] = []

    static func setRoutes(_ newRoutes: [String: Route]) {
        lock.lock()
        routes = newRoutes
        requests = []
        lock.unlock()
    }

    static func reset() {
        lock.lock()
        routes = [:]
        requests = []
        lock.unlock()
    }

    static func recordedRequests() -> [URLRequest] {
        lock.lock()
        let output = requests
        lock.unlock()
        return output
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.scheme == "http" || request.url?.scheme == "https"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        Self.record(request)

        guard let route = Self.route(for: url) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        switch route {
        case .redirect(let location):
            let response = HTTPURLResponse(
                url: url,
                statusCode: 302,
                httpVersion: "HTTP/1.1",
                headerFields: ["Location": location]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)

        case .html(let html):
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "text/html; charset=utf-8"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(html.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}

    private static func record(_ request: URLRequest) {
        lock.lock()
        requests.append(request)
        lock.unlock()
    }

    private static func route(for url: URL) -> Route? {
        lock.lock()
        let output = routes[url.absoluteString]
        lock.unlock()
        return output
    }
}
