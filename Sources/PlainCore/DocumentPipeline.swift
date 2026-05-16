import Foundation

public struct DocumentPipeline: Sendable {
    public var normalizer: URLNormalizer
    public var fetcher: PageFetcher
    public var sanitizer: Sanitizer
    public var extractor: DocumentExtractor
    public var imageFetcher: ImageFetcher

    public init(
        normalizer: URLNormalizer = URLNormalizer(),
        fetcher: PageFetcher = PageFetcher(),
        sanitizer: Sanitizer = Sanitizer(),
        extractor: DocumentExtractor = DocumentExtractor(),
        imageFetcher: ImageFetcher = ImageFetcher()
    ) {
        self.normalizer = normalizer
        self.fetcher = fetcher
        self.sanitizer = sanitizer
        self.extractor = extractor
        self.imageFetcher = imageFetcher
    }

    public func load(
        _ input: String,
        relativeTo baseURL: URL? = nil,
        fetchImages: Bool = true
    ) async throws -> DocumentModel {
        try await loadWithMetrics(input, relativeTo: baseURL, fetchImages: fetchImages).document
    }

    public func loadWithMetrics(
        _ input: String,
        relativeTo baseURL: URL? = nil,
        fetchImages: Bool = true
    ) async throws -> (document: DocumentModel, pageMetrics: PageFetchMetrics, imageMetrics: ImageFetchMetrics) {
        let normalizedURL = try normalizer.normalize(input, baseURL: baseURL)
        let fetchedResult = try await fetcher.fetchWithMetrics(normalizedURL)
        let fetched = fetchedResult.document
        let sanitized = try sanitizer.sanitize(html: fetched.html, baseURL: fetched.finalURL)
        let extracted = try extractor.extract(
            sanitizedHTML: sanitized,
            sourceURL: fetched.url,
            finalURL: fetched.finalURL,
            fetchedAt: fetched.fetchedAt
        )

        guard fetchImages else {
            return (extracted, fetchedResult.metrics, ImageFetchMetrics(candidateCount: extracted.images.count))
        }

        let imageResult = await imageFetcher.fetchImagesWithMetrics(for: extracted)
        return (imageResult.document, fetchedResult.metrics, imageResult.metrics)
    }
}
