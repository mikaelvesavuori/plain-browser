import Darwin
import Foundation

public struct ResolvedAddressValidator: Sendable {
    public typealias Resolver = @Sendable (String) async throws -> [String]

    public var safetyValidator: URLSafetyValidator
    private let resolver: Resolver
    private let requiresResolvedAddresses: Bool

    public init(
        safetyValidator: URLSafetyValidator = URLSafetyValidator(),
        requiresResolvedAddresses: Bool = true,
        resolver: Resolver? = nil
    ) {
        self.safetyValidator = safetyValidator
        self.requiresResolvedAddresses = requiresResolvedAddresses
        self.resolver = resolver ?? SystemDNSResolver.resolve
    }

    public static var staticOnly: ResolvedAddressValidator {
        ResolvedAddressValidator(requiresResolvedAddresses: false) { _ in [] }
    }

    public func validate(_ url: URL) async throws {
        try safetyValidator.validate(url)

        guard let host = safetyValidator.normalizedHost(from: url) else {
            throw PlainError.blockedTargetURL("The URL does not have a valid hostname.")
        }

        guard !safetyValidator.isIPAddressLiteral(host) else {
            return
        }

        let resolvedAddresses = try await resolver(host)
        guard !resolvedAddresses.isEmpty || !requiresResolvedAddresses else {
            throw PlainError.dnsResolutionFailed(host)
        }

        for address in resolvedAddresses {
            try safetyValidator.validateResolvedAddress(address, for: host)
        }
    }
}

private enum SystemDNSResolver {
    static func resolve(_ host: String) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    continuation.resume(returning: try resolveSynchronously(host))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func resolveSynchronously(_ host: String) throws -> [String] {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        hints.ai_protocol = IPPROTO_TCP

        var result: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(host, nil, &hints, &result)
        guard status == 0 else {
            throw PlainError.dnsResolutionFailed(host)
        }

        defer {
            if let result {
                freeaddrinfo(result)
            }
        }

        var addresses: [String] = []
        var cursor = result
        while let current = cursor {
            if let address = stringAddress(from: current.pointee) {
                addresses.append(address)
            }
            cursor = current.pointee.ai_next
        }

        return Array(Set(addresses)).sorted()
    }

    private static func stringAddress(from info: addrinfo) -> String? {
        guard let socketAddress = info.ai_addr else {
            return nil
        }

        switch Int32(info.ai_family) {
        case AF_INET:
            var address = socketAddress.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                $0.pointee.sin_addr
            }
            return stringIPv4Address(&address)
        case AF_INET6:
            var address = socketAddress.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
                $0.pointee.sin6_addr
            }
            return stringIPv6Address(&address)
        default:
            return nil
        }
    }

    private static func stringIPv4Address(_ address: inout in_addr) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        return buffer.withUnsafeMutableBufferPointer { pointer in
            guard let baseAddress = pointer.baseAddress,
                  inet_ntop(AF_INET, &address, baseAddress, socklen_t(INET_ADDRSTRLEN)) != nil else {
                return nil
            }
            return String(cString: baseAddress)
        }
    }

    private static func stringIPv6Address(_ address: inout in6_addr) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        return buffer.withUnsafeMutableBufferPointer { pointer in
            guard let baseAddress = pointer.baseAddress,
                  inet_ntop(AF_INET6, &address, baseAddress, socklen_t(INET6_ADDRSTRLEN)) != nil else {
                return nil
            }
            return String(cString: baseAddress)
        }
    }
}
