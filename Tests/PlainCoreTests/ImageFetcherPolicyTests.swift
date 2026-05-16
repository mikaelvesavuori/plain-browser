import PlainCore
import XCTest

final class ImageFetcherPolicyTests: XCTestCase {
    override func tearDown() {
        ImageRedirectTestURLProtocol.reset()
        super.tearDown()
    }

    func testDefaultImagePolicyLoadsDocumentImagesCookieFreeCompatible() {
        let fetcher = ImageFetcher()

        XCTAssertTrue(fetcher.loadThirdPartyImages)
        XCTAssertEqual(fetcher.timeout, 15)
        XCTAssertEqual(fetcher.userAgent, "Plain/0.1")
        XCTAssertEqual(fetcher.maxImageBytes, 12_000_000)
        XCTAssertEqual(fetcher.maxRedirects, 10)
    }

    func testImageFetcherBlocksUnsafeRedirectTargetsBeforeFetchingThem() async throws {
        let imageURL = URL(string: "https://images.example.com/photo.png")!
        ImageRedirectTestURLProtocol.setRoutes([
            imageURL.absoluteString: .redirect(location: "http://127.0.0.1/private.png")
        ])

        let document = DocumentModel(
            sourceURL: URL(string: "https://example.com/read")!,
            finalURL: URL(string: "https://example.com/read")!,
            elements: [.image(ImageRef(sourceURL: imageURL))],
            images: [ImageRef(sourceURL: imageURL)],
            fetchedAt: Date(),
            extractionQuality: .strong
        )

        let cacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fetcher = ImageFetcher(
            cache: ImageCache(rootDirectory: cacheDirectory),
            userAgent: "PlainTests/1.0",
            addressValidator: .staticOnly,
            sessionConfigurationFactory: { privacyConfiguration in
                let configuration = privacyConfiguration.makeURLSessionConfiguration()
                configuration.protocolClasses = [ImageRedirectTestURLProtocol.self]
                return configuration
            }
        )

        let output = await fetcher.fetchImagesWithMetrics(for: document)

        XCTAssertEqual(output.metrics.requestedCount, 1)
        XCTAssertEqual(output.metrics.failedCount, 1)
        XCTAssertNil(output.document.images.first?.localPath)
        XCTAssertEqual(ImageRedirectTestURLProtocol.recordedRequests().map { $0.url?.absoluteString }, [
            imageURL.absoluteString
        ])
    }

    func testImageFetcherBlocksRemoteSVGImages() async throws {
        let imageURL = URL(string: "https://images.example.com/icon.svg")!
        ImageRedirectTestURLProtocol.setRoutes([
            imageURL.absoluteString: .image(Data("<svg></svg>".utf8), mimeType: "image/svg+xml")
        ])

        let document = DocumentModel(
            sourceURL: URL(string: "https://example.com/read")!,
            finalURL: URL(string: "https://example.com/read")!,
            elements: [.image(ImageRef(sourceURL: imageURL, mimeType: "image/svg+xml"))],
            images: [ImageRef(sourceURL: imageURL, mimeType: "image/svg+xml")],
            fetchedAt: Date(),
            extractionQuality: .strong
        )

        let cacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fetcher = ImageFetcher(
            cache: ImageCache(rootDirectory: cacheDirectory),
            addressValidator: .staticOnly,
            sessionConfigurationFactory: { privacyConfiguration in
                let configuration = privacyConfiguration.makeURLSessionConfiguration()
                configuration.protocolClasses = [ImageRedirectTestURLProtocol.self]
                return configuration
            }
        )

        let output = await fetcher.fetchImagesWithMetrics(for: document)

        XCTAssertEqual(output.metrics.candidateCount, 1)
        XCTAssertEqual(output.metrics.requestedCount, 0)
        XCTAssertNil(output.document.images.first?.localPath)
        XCTAssertTrue(ImageRedirectTestURLProtocol.recordedRequests().isEmpty)
    }
}

private final class ImageRedirectTestURLProtocol: URLProtocol {
    enum Route {
        case redirect(location: String)
        case image(Data, mimeType: String)
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

        Self.lock.lock()
        Self.requests.append(request)
        let route = Self.routes[url.absoluteString]
        Self.lock.unlock()

        switch route {
        case .redirect(let location):
            let response = HTTPURLResponse(
                url: url,
                statusCode: 302,
                httpVersion: nil,
                headerFields: ["Location": location]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
        case .image(let data, let mimeType):
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": mimeType]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case .none:
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
        }
    }

    override func stopLoading() {}
}
