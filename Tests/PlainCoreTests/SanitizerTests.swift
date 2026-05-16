import Foundation
import PlainCore
import XCTest

final class SanitizerTests: XCTestCase {
    func testSanitizerRemovesScriptsEventsFormsAndTrackingPixels() throws {
        let html = try fixture(named: "article")
        let sanitized = try Sanitizer().sanitize(
            html: html,
            baseURL: URL(string: "https://example.com/read")!
        )

        XCTAssertFalse(sanitized.html.contains("<script"))
        XCTAssertFalse(sanitized.html.contains("<style"))
        XCTAssertFalse(sanitized.html.contains("onclick"))
        XCTAssertFalse(sanitized.html.contains("javascript:"))
        XCTAssertFalse(sanitized.html.contains("pixel.gif"))
    }

    func testSanitizerPreservesOnlyInertJsonLDMetadataScripts() throws {
        let html = """
        <!doctype html>
        <html>
          <head>
            <script>alert("tracking")</script>
            <script type="application/ld+json" nonce="abc">{"@type":"NewsArticle","headline":"Metadata"}</script>
          </head>
          <body><article><p>Readable text.</p></article></body>
        </html>
        """

        let sanitized = try Sanitizer().sanitize(
            html: html,
            baseURL: URL(string: "https://example.com/read")!
        )

        XCTAssertFalse(sanitized.html.contains("alert"))
        XCTAssertFalse(sanitized.html.contains("nonce"))
        XCTAssertTrue(sanitized.html.contains("application/ld+json"))
        XCTAssertTrue(sanitized.html.contains("NewsArticle"))
    }

    func testSanitizerRemovesNonDocumentMediaButKeepsPictureSources() throws {
        let html = """
        <!doctype html>
        <html>
          <body>
            <video src="/movie.mp4"><source src="/movie.webm" type="video/webm"></video>
            <audio src="/sound.mp3"></audio>
            <picture>
              <source srcset="/large.webp 1200w" type="image/webp">
              <img src="/fallback.jpg" alt="Meaningful image">
            </picture>
          </body>
        </html>
        """

        let sanitized = try Sanitizer().sanitize(
            html: html,
            baseURL: URL(string: "https://example.com/read")!
        )

        XCTAssertFalse(sanitized.html.contains("<video"))
        XCTAssertFalse(sanitized.html.contains("movie.mp4"))
        XCTAssertFalse(sanitized.html.contains("<audio"))
        XCTAssertFalse(sanitized.html.contains("sound.mp3"))
        XCTAssertTrue(sanitized.html.contains("<picture"))
        XCTAssertTrue(sanitized.html.contains("large.webp"))
        XCTAssertTrue(sanitized.html.contains("fallback.jpg"))
    }

    private func fixture(named name: String) throws -> String {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "html", subdirectory: "Fixtures"))
        return try String(contentsOf: url, encoding: .utf8)
    }
}
