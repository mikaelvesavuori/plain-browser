import Foundation

public struct URLHandoffParser: Sendable {
    public init() {}

    public func sourceURL(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if let url = URL(string: trimmed) {
            return sourceURL(from: url)
        }

        return nil
    }

    public func sourceURL(from url: URL) -> URL? {
        if isReadableWebURL(url) {
            return url
        }

        guard let scheme = url.scheme?.lowercased(),
              scheme == "plain" else {
            return nil
        }

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let encoded = components.queryItems?.first(where: { $0.name == "url" })?.value,
           let sourceURL = URL(string: encoded),
           isReadableWebURL(sourceURL) {
            return sourceURL
        }

        return nil
    }

    private func isReadableWebURL(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased()
        return scheme == "http" || scheme == "https"
    }
}
