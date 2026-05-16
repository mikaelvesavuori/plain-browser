import Foundation

public struct ImageFetcher: Sendable {
    public var cache: ImageCache
    public var maxImageBytes: Int
    public var maxRedirects: Int
    public var loadThirdPartyImages: Bool
    public var timeout: TimeInterval
    public var userAgent: String
    public var safetyValidator: URLSafetyValidator
    public var addressValidator: ResolvedAddressValidator
    private let sessionConfigurationFactory: @Sendable (FetchPrivacyConfiguration) -> URLSessionConfiguration

    public init(
        cache: ImageCache = ImageCache(),
        maxImageBytes: Int = 12_000_000,
        maxRedirects: Int = 10,
        loadThirdPartyImages: Bool = true,
        timeout: TimeInterval = 15,
        userAgent: String = "Plain/0.1",
        safetyValidator: URLSafetyValidator = URLSafetyValidator(),
        addressValidator: ResolvedAddressValidator? = nil,
        sessionConfigurationFactory: @escaping @Sendable (FetchPrivacyConfiguration) -> URLSessionConfiguration = {
            $0.makeURLSessionConfiguration()
        }
    ) {
        self.cache = cache
        self.maxImageBytes = maxImageBytes
        self.maxRedirects = maxRedirects
        self.loadThirdPartyImages = loadThirdPartyImages
        self.timeout = timeout
        self.userAgent = userAgent
        self.safetyValidator = safetyValidator
        self.addressValidator = addressValidator ?? ResolvedAddressValidator(safetyValidator: safetyValidator)
        self.sessionConfigurationFactory = sessionConfigurationFactory
    }

    public func fetchImages(for document: DocumentModel) async -> DocumentModel {
        await fetchImagesWithMetrics(for: document).document
    }

    public func fetchImagesWithMetrics(for document: DocumentModel) async -> (document: DocumentModel, metrics: ImageFetchMetrics) {
        var updated = document
        var replacements: [URL: ImageRef] = [:]
        var metrics = ImageFetchMetrics()
        let startedAt = DispatchTime.now().uptimeNanoseconds

        var imagesToFetch = document.images
        if let heroImage = document.heroImage, !imagesToFetch.contains(where: { $0.sourceURL == heroImage.sourceURL }) {
            imagesToFetch.append(heroImage)
        }

        metrics.candidateCount = imagesToFetch.count

        for image in imagesToFetch where shouldFetch(image, for: document.finalURL) {
            if let cachedURL = cache.existingLocalURL(for: image.sourceURL, mimeType: image.mimeType) {
                var cached = image
                cached.localPath = cachedURL
                replacements[image.sourceURL] = cached
                metrics.cacheHitCount += 1
                continue
            }

            metrics.requestedCount += 1
            if let fetched = await fetchImage(image) {
                replacements[image.sourceURL] = fetched.image
                metrics.succeededCount += 1
                metrics.downloadedBytes += fetched.bytes
            } else {
                metrics.failedCount += 1
            }
        }

        metrics.durationMilliseconds = milliseconds(from: startedAt, to: DispatchTime.now().uptimeNanoseconds)

        guard !replacements.isEmpty else {
            return (updated, metrics)
        }

        updated.images = updated.images.map { replacements[$0.sourceURL] ?? $0 }
        if let heroImage = updated.heroImage {
            updated.heroImage = replacements[heroImage.sourceURL] ?? heroImage
        }
        updated.elements = updated.elements.map { $0.replacingImages(replacements) }

        return (updated, metrics)
    }

    private func shouldFetch(_ image: ImageRef, for pageURL: URL) -> Bool {
        let imageURL = image.sourceURL
        guard !isBlockedRemoteImageType(image) else {
            return false
        }

        guard safetyValidator.isSafe(imageURL) else {
            return false
        }

        guard !loadThirdPartyImages else {
            return true
        }

        guard let imageHost = imageURL.host(percentEncoded: false)?.lowercased(),
              let pageHost = pageURL.host(percentEncoded: false)?.lowercased() else {
            return false
        }

        return imageHost == pageHost || imageHost.hasSuffix(".\(pageHost)")
    }

    private func fetchImage(_ image: ImageRef) async -> (image: ImageRef, bytes: Int)? {
        guard !isBlockedRemoteImageType(image) else {
            return nil
        }

        let session = URLSession(configuration: sessionConfigurationFactory(FetchPrivacyConfiguration(timeout: timeout)))
        defer {
            session.finishTasksAndInvalidate()
        }

        do {
            try await addressValidator.validate(image.sourceURL)

            var currentURL = image.sourceURL
            var redirectsFollowed = 0
            var data = Data()
            var response: URLResponse?

            while true {
                let request = plainRequest(
                    for: currentURL,
                    timeout: timeout,
                    userAgent: userAgent,
                    kind: .image
                )
                (data, response) = try await session.data(for: request, delegate: NoAutomaticRedirectDelegate())

                guard let httpResponse = response as? HTTPURLResponse else {
                    return nil
                }

                guard let redirectURL = try HTTPRedirect.target(from: httpResponse, baseURL: currentURL) else {
                    break
                }

                guard redirectsFollowed < maxRedirects else {
                    return nil
                }

                try await addressValidator.validate(redirectURL)
                redirectsFollowed += 1
                currentURL = redirectURL
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  data.count <= maxImageBytes,
                  isAllowedImageMimeType(httpResponse.mimeType),
                  safetyValidator.isSafe(httpResponse.url ?? image.sourceURL) else {
                return nil
            }

            let mimeType = httpResponse.mimeType
            let localURL = try cache.store(data: data, sourceURL: image.sourceURL, mimeType: mimeType)

            var updated = image
            updated.localPath = localURL
            updated.mimeType = mimeType
            return (updated, data.count)
        } catch {
            return nil
        }
    }

    private func isBlockedRemoteImageType(_ image: ImageRef) -> Bool {
        if normalizedMimeType(image.mimeType) == "image/svg+xml" {
            return true
        }

        return image.sourceURL.pathExtension.lowercased() == "svg"
    }

    private func isAllowedImageMimeType(_ mimeType: String?) -> Bool {
        guard let normalized = normalizedMimeType(mimeType),
              normalized.hasPrefix("image/") else {
            return false
        }

        return normalized != "image/svg+xml"
    }

    private func normalizedMimeType(_ mimeType: String?) -> String? {
        mimeType?
            .lowercased()
            .split(separator: ";", maxSplits: 1)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

}

private extension DocumentElement {
    func replacingImages(_ replacements: [URL: ImageRef]) -> DocumentElement {
        switch self {
        case .image(let image):
            return .image(replacements[image.sourceURL] ?? image)
        case .figure(let image, let caption):
            return .figure(image: replacements[image.sourceURL] ?? image, caption: caption)
        case .blockquote(let children):
            return .blockquote(children.map { $0.replacingImages(replacements) })
        case .list(let ordered, let items):
            return .list(
                ordered: ordered,
                items: items.map { row in row.map { $0.replacingImages(replacements) } }
            )
        default:
            return self
        }
    }
}
