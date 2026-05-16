import Foundation

public struct PageFetchMetrics: Codable, Equatable, Sendable {
    public var durationMilliseconds: Double
    public var responseBytes: Int
    public var statusCode: Int
    public var finalURL: URL

    public init(
        durationMilliseconds: Double,
        responseBytes: Int,
        statusCode: Int,
        finalURL: URL
    ) {
        self.durationMilliseconds = durationMilliseconds
        self.responseBytes = responseBytes
        self.statusCode = statusCode
        self.finalURL = finalURL
    }
}

public struct ImageFetchMetrics: Codable, Equatable, Sendable {
    public var candidateCount: Int
    public var requestedCount: Int
    public var cacheHitCount: Int
    public var succeededCount: Int
    public var failedCount: Int
    public var downloadedBytes: Int
    public var durationMilliseconds: Double

    public init(
        candidateCount: Int = 0,
        requestedCount: Int = 0,
        cacheHitCount: Int = 0,
        succeededCount: Int = 0,
        failedCount: Int = 0,
        downloadedBytes: Int = 0,
        durationMilliseconds: Double = 0
    ) {
        self.candidateCount = candidateCount
        self.requestedCount = requestedCount
        self.cacheHitCount = cacheHitCount
        self.succeededCount = succeededCount
        self.failedCount = failedCount
        self.downloadedBytes = downloadedBytes
        self.durationMilliseconds = durationMilliseconds
    }
}
