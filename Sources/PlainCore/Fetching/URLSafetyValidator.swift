import Foundation

public struct URLSafetyValidator: Sendable {
    private let blockedHostnames: Set<String> = [
        "localhost",
        "0.0.0.0",
        "127.0.0.1",
        "255.255.255.255",
        "::1",
        "[::1]",
        "::",
        "[::]"
    ]

    private let blockedHostSuffixes = [
        ".localhost",
        ".local",
        ".localdomain",
        ".internal",
        ".home.arpa"
    ]

    public init() {}

    public func validate(_ url: URL) throws {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw PlainError.unsupportedScheme(url.scheme ?? "missing")
        }

        if url.user != nil || url.password != nil {
            throw PlainError.blockedTargetURL("URLs with usernames or passwords are not allowed.")
        }

        guard let host = normalizedHost(from: url), !host.isEmpty else {
            throw PlainError.blockedTargetURL("The URL does not have a valid hostname.")
        }

        try validateResolvedAddress(host, for: host)
    }

    public func validateResolvedAddress(_ address: String, for hostname: String) throws {
        let host = normalizeHost(address)
        if isBlockedHostname(host) || isPrivateIPv4(host) || isPrivateIPv6(host) {
            throw PlainError.blockedTargetURL("Local and private network addresses are not allowed by default.")
        }
    }

    public func normalizedHost(from url: URL) -> String? {
        let rawHost = url.host(percentEncoded: false) ?? url.host
        let normalized = normalizeHost(rawHost ?? "")
        return normalized.isEmpty ? nil : normalized
    }

    public func isIPAddressLiteral(_ hostname: String) -> Bool {
        let host = normalizeHost(hostname)
        return isIPv4Address(host) || host.contains(":")
    }

    public func isSafe(_ url: URL) -> Bool {
        do {
            try validate(url)
            return true
        } catch {
            return false
        }
    }

    private func normalizeHost(_ hostname: String) -> String {
        let trimmed = hostname
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))

        guard !trimmed.isEmpty else {
            return ""
        }

        if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
            return String(trimmed.dropFirst().dropLast())
        }

        return trimmed
    }

    private func isBlockedHostname(_ hostname: String) -> Bool {
        if blockedHostnames.contains(hostname) {
            return true
        }

        return blockedHostSuffixes.contains { suffix in
            hostname.hasSuffix(suffix)
        }
    }

    private func isPrivateIPv4(_ hostname: String) -> Bool {
        guard isIPv4Address(hostname) else {
            return false
        }

        let parts = hostname.split(separator: ".", omittingEmptySubsequences: false)
        var octets: [Int] = []
        for part in parts {
            octets.append(Int(part) ?? 0)
        }

        let a = octets[0]
        let b = octets[1]
        let c = octets[2]

        if a == 10 || a == 127 || a == 0 { return true }
        if a == 169 && b == 254 { return true }
        if a == 172 && (16...31).contains(b) { return true }
        if a == 192 && b == 168 { return true }
        if a == 100 && (64...127).contains(b) { return true }
        if a == 198 && (b == 18 || b == 19) { return true }
        if a == 192 && b == 0 && c == 0 { return true }
        if a >= 224 { return true }

        return false
    }

    private func isIPv4Address(_ hostname: String) -> Bool {
        let parts = hostname.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else {
            return false
        }

        for part in parts {
            guard part.allSatisfy(\.isNumber), let value = Int(part), (0...255).contains(value) else {
                return false
            }
        }
        return true
    }

    private func isPrivateIPv6(_ hostname: String) -> Bool {
        let host = hostname.lowercased()
        guard host.contains(":") else {
            return false
        }

        if host == "::1" || host == "::" {
            return true
        }

        if host.hasPrefix("fc") || host.hasPrefix("fd") {
            return true
        }

        if host.hasPrefix("fe8")
            || host.hasPrefix("fe9")
            || host.hasPrefix("fea")
            || host.hasPrefix("feb") {
            return true
        }

        if host.hasPrefix("ff") {
            return true
        }

        if host.hasPrefix("::ffff:") {
            let mappedIPv4 = String(host.dropFirst("::ffff:".count))
            return isPrivateIPv4(mappedIPv4)
        }

        return false
    }
}
