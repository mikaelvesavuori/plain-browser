import Foundation
import PlainCore
import XCTest

final class URLSafetyValidatorTests: XCTestCase {
    func testAllowsPublicWebURLs() throws {
        let validator = URLSafetyValidator()

        XCTAssertNoThrow(try validator.validate(URL(string: "https://example.com/read")!))
    }

    func testBlocksLocalhostAndPrivateRanges() {
        let validator = URLSafetyValidator()

        for value in [
            "http://localhost:3000",
            "http://127.0.0.1",
            "http://10.0.0.5",
            "http://172.16.0.1",
            "http://192.168.1.20",
            "http://169.254.1.1",
            "http://[::1]",
            "http://[fd00::1]"
        ] {
            XCTAssertThrowsError(try validator.validate(URL(string: value)!))
        }
    }

    func testBlocksCredentials() {
        let validator = URLSafetyValidator()

        XCTAssertThrowsError(try validator.validate(URL(string: "https://user:pass@example.com/read")!))
    }

    func testResolvedAddressValidatorBlocksHostsResolvingToPrivateAddresses() async throws {
        let validator = ResolvedAddressValidator { host in
            XCTAssertEqual(host, "example.com")
            return ["127.0.0.1"]
        }

        await XCTAssertThrowsErrorAsync {
            try await validator.validate(URL(string: "https://example.com/read")!)
        }
    }

    func testResolvedAddressValidatorAllowsHostsResolvingToPublicAddresses() async throws {
        let validator = ResolvedAddressValidator { host in
            XCTAssertEqual(host, "example.com")
            return ["93.184.216.34", "2606:2800:220:1:248:1893:25c8:1946"]
        }

        try await validator.validate(URL(string: "https://example.com/read")!)
    }
}

private func XCTAssertThrowsErrorAsync(
    _ expression: () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await expression()
        XCTFail("Expected async expression to throw.", file: file, line: line)
    } catch {}
}
