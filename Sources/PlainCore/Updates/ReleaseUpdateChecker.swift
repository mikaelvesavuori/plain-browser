import Foundation

public struct AppUpdate: Equatable, Sendable {
    public var latestVersion: String
    public var releaseURL: URL

    public init(latestVersion: String, releaseURL: URL) {
        self.latestVersion = latestVersion
        self.releaseURL = releaseURL
    }
}

public struct ReleaseUpdateChecker: Sendable {
    public var latestReleaseURL: URL
    public var session: URLSession
    public var userAgent: String

    public init(
        latestReleaseURL: URL = URL(string: "https://api.github.com/repos/mikaelvesavuori/plain-browser/releases/latest")!,
        session: URLSession = URLSession(configuration: .ephemeral),
        userAgent: String = "Plain"
    ) {
        self.latestReleaseURL = latestReleaseURL
        self.session = session
        self.userAgent = userAgent
    }

    public func check(currentVersion: String) async -> AppUpdate? {
        guard PlainVersion(currentVersion) != nil else {
            return nil
        }

        var request = URLRequest(url: latestReleaseURL, timeoutInterval: 8)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return nil
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            guard !release.prerelease,
                  let latest = PlainVersion(release.tagName),
                  let current = PlainVersion(currentVersion),
                  latest > current,
                  let releaseURL = URL(string: release.htmlURL) else {
                return nil
            }

            return AppUpdate(latestVersion: latest.displayString, releaseURL: releaseURL)
        } catch {
            return nil
        }
    }
}

private struct GitHubRelease: Decodable {
    var tagName: String
    var htmlURL: String
    var prerelease: Bool

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case prerelease
    }
}

struct PlainVersion: Comparable, Equatable {
    var parts: [Int]

    init?(_ rawValue: String) {
        var trimmed = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.first == "v" || trimmed.first == "V" {
            trimmed.removeFirst()
        }

        guard !trimmed.isEmpty else {
            return nil
        }

        let components = trimmed.split(separator: ".")
        guard !components.isEmpty else {
            return nil
        }

        var parsedParts: [Int] = []
        for component in components {
            guard !component.isEmpty,
                  component.allSatisfy(\.isNumber),
                  let value = Int(component) else {
                return nil
            }
            parsedParts.append(value)
        }

        while parsedParts.count < 3 {
            parsedParts.append(0)
        }

        parts = parsedParts
    }

    var displayString: String {
        var normalized = parts
        while normalized.count > 1 && normalized.last == 0 {
            normalized.removeLast()
        }
        return normalized.map(String.init).joined(separator: ".")
    }

    static func < (lhs: PlainVersion, rhs: PlainVersion) -> Bool {
        let count = max(lhs.parts.count, rhs.parts.count)
        for index in 0..<count {
            let left = index < lhs.parts.count ? lhs.parts[index] : 0
            let right = index < rhs.parts.count ? rhs.parts[index] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }
}
