import Foundation
import PlainCore
import XCTest

final class WorkerInspiredHeuristicsTests: XCTestCase {
    func testExtractorDropsShortUIChromeAndDecorativeImages() throws {
        let html = """
        <!doctype html>
        <html>
          <head><title>Chrome Filter</title></head>
          <body>
            <article>
              <h1>Chrome Filter</h1>
              <p>Subscribe</p>
              <p>Share this article</p>
              <img class="author-avatar" src="/avatar.png" alt="Author photo" width="80" height="80">
              <p>This is the actual article paragraph with enough meaningful content to survive the chrome filter cleanly.</p>
              <img src="/hero.png" alt="Article hero" width="900" height="500">
            </article>
          </body>
        </html>
        """

        let baseURL = URL(string: "https://example.com/article")!
        let sanitized = try Sanitizer().sanitize(html: html, baseURL: baseURL)

        let document = try DocumentExtractor().extract(
            sanitizedHTML: sanitized,
            sourceURL: baseURL,
            finalURL: baseURL,
            fetchedAt: Date(timeIntervalSince1970: 0)
        )

        let exportedText = DocumentTextExporter().plainText(from: document)
        XCTAssertFalse(exportedText.contains("Subscribe"))
        XCTAssertFalse(exportedText.contains("Share this article"))
        XCTAssertTrue(exportedText.contains("actual article paragraph"))
        XCTAssertEqual(document.images.map(\.sourceURL.absoluteString), ["https://example.com/hero.png"])
    }
}
