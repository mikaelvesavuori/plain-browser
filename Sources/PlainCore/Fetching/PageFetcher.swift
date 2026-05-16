import Foundation

public struct PageFetcher: Sendable {
    public var maxResponseBytes: Int
    public var maxRedirects: Int
    public var timeout: TimeInterval
    public var userAgent: String
    public var safetyValidator: URLSafetyValidator
    public var addressValidator: ResolvedAddressValidator
    public var privacyConfiguration: FetchPrivacyConfiguration
    private let sessionConfigurationFactory: @Sendable (FetchPrivacyConfiguration) -> URLSessionConfiguration

    public init(
        maxResponseBytes: Int = 2_000_000,
        maxRedirects: Int = 10,
        timeout: TimeInterval = 15,
        userAgent: String = "Plain/0.1",
        safetyValidator: URLSafetyValidator = URLSafetyValidator(),
        addressValidator: ResolvedAddressValidator? = nil,
        sessionConfigurationFactory: @escaping @Sendable (FetchPrivacyConfiguration) -> URLSessionConfiguration = {
            $0.makeURLSessionConfiguration()
        }
    ) {
        self.maxResponseBytes = maxResponseBytes
        self.maxRedirects = maxRedirects
        self.timeout = timeout
        self.userAgent = userAgent
        self.safetyValidator = safetyValidator
        self.addressValidator = addressValidator ?? ResolvedAddressValidator(safetyValidator: safetyValidator)
        self.privacyConfiguration = FetchPrivacyConfiguration(timeout: timeout)
        self.sessionConfigurationFactory = sessionConfigurationFactory
    }

    public func fetch(_ url: URL) async throws -> FetchedDocument {
        try await fetchWithMetrics(url).document
    }

    public func fetchWithMetrics(_ url: URL) async throws -> (document: FetchedDocument, metrics: PageFetchMetrics) {
        try await addressValidator.validate(url)

        let session = URLSession(configuration: sessionConfigurationFactory(privacyConfiguration))
        defer {
            session.finishTasksAndInvalidate()
        }

        var currentURL = url
        var redirectsFollowed = 0
        var data = Data()
        var response: URLResponse?
        let startedAt = DispatchTime.now().uptimeNanoseconds

        while true {
            let request = plainRequest(
                for: currentURL,
                timeout: timeout,
                userAgent: userAgent,
                kind: .html
            )

            do {
                (data, response) = try await session.data(for: request, delegate: NoAutomaticRedirectDelegate())
            } catch {
                throw PlainError.fetchFailed(error.localizedDescription)
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                throw PlainError.fetchFailed("The server did not return an HTTP response.")
            }

            guard let redirectURL = try HTTPRedirect.target(from: httpResponse, baseURL: currentURL) else {
                break
            }

            guard redirectsFollowed < maxRedirects else {
                throw PlainError.tooManyRedirects(maxRedirects)
            }

            try await validateRedirectTarget(redirectURL)
            redirectsFollowed += 1
            currentURL = redirectURL
        }

        let finishedAt = DispatchTime.now().uptimeNanoseconds

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlainError.fetchFailed("The server did not return an HTTP response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw PlainError.badStatus(httpResponse.statusCode)
        }

        guard data.count <= maxResponseBytes else {
            throw PlainError.responseTooLarge(data.count)
        }

        let mimeType = httpResponse.mimeType?.lowercased()
        guard isHTML(mimeType: mimeType) else {
            throw PlainError.unsupportedContent(mimeType)
        }

        guard let html = decodeHTML(data: data, response: httpResponse) else {
            throw PlainError.decodeFailed
        }

        let finalURL = httpResponse.url ?? currentURL
        try await addressValidator.validate(finalURL)

        let document = FetchedDocument(
            url: url,
            finalURL: finalURL,
            statusCode: httpResponse.statusCode,
            mimeType: mimeType,
            headers: httpResponse.normalizedHeaders,
            html: html,
            fetchedAt: Date()
        )

        let metrics = PageFetchMetrics(
            durationMilliseconds: milliseconds(from: startedAt, to: finishedAt),
            responseBytes: data.count,
            statusCode: httpResponse.statusCode,
            finalURL: finalURL
        )

        return (document, metrics)
    }

    private func validateRedirectTarget(_ url: URL) async throws {
        do {
            try await addressValidator.validate(url)
        } catch PlainError.blockedTargetURL(let reason) {
            throw PlainError.blockedTargetURL("The page redirected to a blocked target. \(reason)")
        } catch PlainError.unsupportedScheme(let scheme) {
            throw PlainError.blockedTargetURL("The page redirected to an unsupported URL scheme: \(scheme).")
        } catch PlainError.dnsResolutionFailed(let host) {
            throw PlainError.blockedTargetURL("The page redirected to a host Plain could not verify: \(host).")
        }
    }

    private func isHTML(mimeType: String?) -> Bool {
        guard let mimeType else {
            return true
        }
        return mimeType.contains("text/html") || mimeType.contains("application/xhtml+xml")
    }

    private func decodeHTML(data: Data, response: HTTPURLResponse) -> String? {
        if let encodingName = response.textEncodingName {
            let cfEncoding = CFStringConvertIANACharSetNameToEncoding(encodingName as CFString)
            if cfEncoding != kCFStringEncodingInvalidId {
                let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
                let encoding = String.Encoding(rawValue: nsEncoding)
                if let decoded = String(data: data, encoding: encoding) {
                    return decoded
                }
            }
        }

        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
    }

}
