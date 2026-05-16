import Foundation

public enum PlainError: LocalizedError, Equatable, Sendable {
    case invalidURL(String)
    case unsupportedScheme(String)
    case fetchFailed(String)
    case badStatus(Int)
    case tooManyRedirects(Int)
    case unsupportedContent(String?)
    case responseTooLarge(Int)
    case blockedTargetURL(String)
    case dnsResolutionFailed(String)
    case decodeFailed
    case extractionFailed

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let value):
            return "Could not understand this URL: \(value)"
        case .unsupportedScheme(let scheme):
            return "Plain only supports http and https links. This link uses \(scheme)."
        case .fetchFailed(let reason):
            return "Could not fetch this page. \(reason)"
        case .badStatus(let statusCode):
            return "The page returned HTTP \(statusCode)."
        case .tooManyRedirects(let limit):
            return "The page redirected too many times (\(limit) redirects)."
        case .unsupportedContent(let mimeType):
            if let mimeType {
                return "This page is \(mimeType), not a readable HTML document."
            }
            return "This page does not appear to be a readable HTML document."
        case .responseTooLarge(let bytes):
            return "The page is too large to read safely (\(bytes) bytes)."
        case .blockedTargetURL(let reason):
            return "Plain blocked this target URL. \(reason)"
        case .dnsResolutionFailed(let host):
            return "Plain could not verify where this host resolves: \(host)"
        case .decodeFailed:
            return "Plain could not decode the page as text."
        case .extractionFailed:
            return "This page appears to require JavaScript or a full browser."
        }
    }
}
