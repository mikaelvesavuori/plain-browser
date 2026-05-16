import Foundation

enum PlainFetchRequestKind {
    case html
    case image

    var acceptHeader: String {
        switch self {
        case .html:
            return "text/html,application/xhtml+xml;q=0.9,*/*;q=0.1"
        case .image:
            return "image/jpeg,image/png,image/webp,image/gif,image/avif,image/*;q=0.8,*/*;q=0.5"
        }
    }
}

func plainRequest(
    for url: URL,
    timeout: TimeInterval,
    userAgent: String,
    kind: PlainFetchRequestKind
) -> URLRequest {
    var request = URLRequest(url: url, timeoutInterval: timeout)
    request.httpMethod = "GET"
    request.httpShouldHandleCookies = false
    request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    request.setValue(kind.acceptHeader, forHTTPHeaderField: "Accept")
    request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
    request.setValue("no-cache", forHTTPHeaderField: "Pragma")
    request.setValue(nil, forHTTPHeaderField: "Cookie")
    request.setValue(nil, forHTTPHeaderField: "Referer")
    request.setValue(nil, forHTTPHeaderField: "Origin")
    return request
}

enum HTTPRedirect {
    static func target(from response: HTTPURLResponse, baseURL: URL) throws -> URL? {
        guard isRedirectStatus(response.statusCode) else {
            return nil
        }

        guard let rawLocation = response.headerValue(named: "Location")?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawLocation.isEmpty else {
            return nil
        }

        guard let url = URL(string: rawLocation, relativeTo: baseURL)?.absoluteURL else {
            throw PlainError.invalidURL(rawLocation)
        }

        return url
    }

    private static func isRedirectStatus(_ statusCode: Int) -> Bool {
        switch statusCode {
        case 301, 302, 303, 307, 308:
            return true
        default:
            return false
        }
    }
}

final class NoAutomaticRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

func milliseconds(from start: UInt64, to end: UInt64) -> Double {
    Double(end - start) / 1_000_000.0
}

extension HTTPURLResponse {
    func headerValue(named name: String) -> String? {
        for (key, value) in allHeaderFields {
            let headerName = String(describing: key)
            guard headerName.caseInsensitiveCompare(name) == .orderedSame else {
                continue
            }
            return String(describing: value)
        }
        return nil
    }

    var normalizedHeaders: [String: String] {
        var values: [String: String] = [:]
        for (key, value) in allHeaderFields {
            values[String(describing: key)] = String(describing: value)
        }
        return values
    }
}
