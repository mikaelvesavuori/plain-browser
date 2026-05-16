import Foundation

public struct SearchEngine: Equatable, Sendable {
    public var name: String
    public var scheme: String
    public var host: String
    public var path: String
    public var queryItemName: String

    public static let mojeek = SearchEngine(
        name: "Mojeek",
        scheme: "https",
        host: "www.mojeek.com",
        path: "/search",
        queryItemName: "q"
    )

    public init(
        name: String,
        scheme: String,
        host: String,
        path: String,
        queryItemName: String
    ) {
        self.name = name
        self.scheme = scheme
        self.host = host
        self.path = path
        self.queryItemName = queryItemName
    }

    public func searchURL(for query: String) throws -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = path
        components.queryItems = [
            URLQueryItem(name: queryItemName, value: query)
        ]

        guard let url = components.url else {
            throw PlainError.invalidURL(query)
        }

        return url
    }
}

public struct URLNormalizer: Sendable {
    private let safetyValidator: URLSafetyValidator
    private let searchEngine: SearchEngine?

    public static let trackingParameters: Set<String> = [
        "utm_source",
        "utm_medium",
        "utm_campaign",
        "utm_term",
        "utm_content",
        "utm_id",
        "fbclid",
        "gclid",
        "dclid",
        "mc_cid",
        "mc_eid",
        "igshid",
        "ref_src"
    ]

    public init(
        safetyValidator: URLSafetyValidator = URLSafetyValidator(),
        searchEngine: SearchEngine? = .mojeek
    ) {
        self.safetyValidator = safetyValidator
        self.searchEngine = searchEngine
    }

    public func normalize(_ input: String, baseURL: URL? = nil) throws -> URL {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PlainError.invalidURL(input)
        }

        let candidate: URL?
        if shouldSearch(trimmed, baseURL: baseURL) {
            guard let searchEngine else {
                throw PlainError.invalidURL(input)
            }
            candidate = try searchEngine.searchURL(for: trimmed)
        } else if let explicitScheme = explicitScheme(in: trimmed),
                  (trimmed.contains("://") || !explicitScheme.contains(".")) {
            candidate = URL(string: trimmed)
        } else if let baseURL, let relative = URL(string: trimmed, relativeTo: baseURL) {
            candidate = relative.absoluteURL
        } else if trimmed.contains("://") {
            candidate = URL(string: trimmed)
        } else {
            candidate = URL(string: "https://\(trimmed)")
        }

        guard let candidate else {
            throw PlainError.invalidURL(input)
        }

        guard let scheme = candidate.scheme?.lowercased() else {
            throw PlainError.invalidURL(input)
        }

        guard scheme == "http" || scheme == "https" else {
            throw PlainError.unsupportedScheme(scheme)
        }

        guard var components = URLComponents(url: candidate, resolvingAgainstBaseURL: true) else {
            throw PlainError.invalidURL(input)
        }

        components.scheme = scheme
        components.host = components.host?.lowercased()
        components.fragment = nil

        if let items = components.queryItems {
            let filtered = items.filter { item in
                !Self.trackingParameters.contains(item.name.lowercased())
            }
            components.queryItems = filtered.isEmpty ? nil : filtered
        }

        guard let url = components.url else {
            throw PlainError.invalidURL(input)
        }

        try safetyValidator.validate(url)

        return url
    }

    private func shouldSearch(_ input: String, baseURL: URL?) -> Bool {
        if explicitScheme(in: input) != nil {
            return false
        }

        if baseURL != nil, looksLikeRelativeURL(input) {
            return false
        }

        return !looksLikeWebAddress(input)
    }

    private func explicitScheme(in input: String) -> String? {
        URLComponents(string: input)?.scheme?.lowercased()
    }

    private func looksLikeRelativeURL(_ input: String) -> Bool {
        input.hasPrefix("/")
            || input.hasPrefix("./")
            || input.hasPrefix("../")
            || input.hasPrefix("?")
            || input.hasPrefix("#")
    }

    private func looksLikeWebAddress(_ input: String) -> Bool {
        if input.contains(where: \.isWhitespace) {
            return false
        }

        let lowercased = input.lowercased()
        if lowercased.hasPrefix("www.") || lowercased.contains("://") {
            return true
        }

        let hostLikePart = lowercased
            .split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
            .first?
            .split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
            .first?
            .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? lowercased

        let hostname = hostLikePart
            .split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? hostLikePart

        if hostname == "localhost" || isIPv4Address(hostname) {
            return true
        }

        return hostname.contains(".")
            && !hostname.hasPrefix(".")
            && !hostname.hasSuffix(".")
    }

    private func isIPv4Address(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else {
            return false
        }

        return parts.allSatisfy { part in
            guard part.allSatisfy(\.isNumber),
                  let number = Int(part) else {
                return false
            }
            return (0...255).contains(number)
        }
    }
}
