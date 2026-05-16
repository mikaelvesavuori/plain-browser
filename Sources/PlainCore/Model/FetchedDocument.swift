import Foundation

public struct FetchedDocument: Sendable {
    public let url: URL
    public let finalURL: URL
    public let statusCode: Int
    public let mimeType: String?
    public let headers: [String: String]
    public let html: String
    public let fetchedAt: Date

    public init(
        url: URL,
        finalURL: URL,
        statusCode: Int,
        mimeType: String?,
        headers: [String: String],
        html: String,
        fetchedAt: Date
    ) {
        self.url = url
        self.finalURL = finalURL
        self.statusCode = statusCode
        self.mimeType = mimeType
        self.headers = headers
        self.html = html
        self.fetchedAt = fetchedAt
    }
}
