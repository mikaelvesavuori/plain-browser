import Foundation
import PlainCore
import XCTest

final class DocumentTextExporterTests: XCTestCase {
    func testExportsPlainTextAndMarkdown() throws {
        let document = DocumentModel(
            sourceURL: URL(string: "https://example.com")!,
            finalURL: URL(string: "https://example.com")!,
            title: "Quiet Web",
            elements: [
                .heading(level: 2, text: "Principle"),
                .paragraph([
                    .text("Treat HTML as "),
                    .strong("source"),
                    .text(" with a "),
                    .link(text: "link", url: URL(string: "https://example.com/link")!)
                ]),
                .searchResult(
                    SearchResult(
                        title: "Quiet result",
                        url: URL(string: "https://example.com/result")!,
                        displayURL: "example.com/result",
                        snippet: "A readable search result."
                    )
                ),
                .codeBlock(language: "swift", code: "let calm = true")
            ],
            images: [],
            fetchedAt: Date(timeIntervalSince1970: 0),
            extractionQuality: .strong
        )

        let exporter = DocumentTextExporter()

        XCTAssertTrue(exporter.plainText(from: document).contains("Treat HTML as source with a link"))
        XCTAssertTrue(exporter.plainText(from: document).contains("Quiet result\nhttps://example.com/result"))
        XCTAssertTrue(exporter.markdown(from: document).contains("Treat HTML as **source** with a [link](https://example.com/link)"))
        XCTAssertTrue(exporter.markdown(from: document).contains("## [Quiet result](https://example.com/result)"))
        XCTAssertTrue(exporter.markdown(from: document).contains("```swift"))
    }
}
