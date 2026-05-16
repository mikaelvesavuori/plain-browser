import Foundation
import PlainCore
import XCTest

final class ExtractionRegressionTests: XCTestCase {
    func testExtractionRegressionCorpus() throws {
        let cases: [RegressionCase] = [
            RegressionCase(
                name: "inline-spacing-links",
                finalURL: URL(string: "https://example.com/read")!,
                expectedTitle: "Inline spacing regression",
                requiredText: [
                    "Det är både gripande och plågsamt att läsa.",
                    "Plain should remain one word.",
                    "Continue reading today.",
                    "Awkward source spacing: evroc. MolnOS, and Polestar."
                ],
                forbiddenText: [
                    "bådegripande",
                    "MolnOS ,",
                    "Polestar ."
                ]
            ),
            RegressionCase(
                name: "messy-jsonld-div-article",
                finalURL: URL(string: "https://messy.example.com/story/42")!,
                expectedTitle: "JSON-LD headline wins",
                expectedSiteName: "Messy Daily",
                expectedAuthor: "Structured Writer",
                expectedHeroImageURL: "https://messy.example.com/images/story-hero.jpg",
                requiredText: [
                    "first meaningful paragraph",
                    "third meaningful paragraph"
                ],
                forbiddenText: [
                    "Subscribe to every update",
                    "Read more"
                ]
            ),
            RegressionCase(
                name: "evroc-marketing-video-shell",
                finalURL: URL(string: "https://evroc.example.com/")!,
                expectedTitle: "evroc",
                expectedHeroImageURL: "https://evroc.example.com/share.jpg",
                expectedImageURLs: [],
                requiredText: [
                    "The European Cloud",
                    "Cloud Services",
                    "secure European infrastructure"
                ],
                forbiddenText: [
                    "evroc_console_4.mp4"
                ]
            ),
            RegressionCase(
                name: "evroc-background-images",
                finalURL: URL(string: "https://evroc.example.com/")!,
                expectedTitle: "evroc",
                expectedHeroImageURL: "https://evroc.example.com/share.jpg",
                expectedImageURLs: [
                    "https://evroc.example.com/static/product-dashboard.jpg"
                ],
                requiredText: [
                    "The European Cloud",
                    "Built for European infrastructure",
                    "skip gradient, texture, and other background-only assets"
                ],
                forbiddenText: [
                    "Abstract gradient background",
                    "Decorative texture"
                ]
            ),
            RegressionCase(
                name: "hacker-news-frontpage",
                finalURL: URL(string: "https://news.ycombinator.com/")!,
                expectedTitle: "Hacker News",
                expectedSiteName: "Hacker News",
                expectedSearchResultCount: 5,
                firstSearchResultTitle: "A practical paper on small software",
                firstSearchResultURL: "https://example.com/research-paper",
                requiredText: [
                    "Ask HN: What are you using for focused reading?",
                    "Measuring energy use in a tiny browser",
                    "The weird shape of modern HTML",
                    "Building quiet native Mac tools"
                ],
                forbiddenText: [
                    "128 comments",
                    "Hacker News new past ask show"
                ]
            ),
            RegressionCase(
                name: "mojeek-results",
                finalURL: URL(string: "https://www.mojeek.com/search?q=mikael%20vesavuori")!,
                expectedTitle: "Search: mikael vesavuori",
                expectedSiteName: "Mojeek",
                expectedSearchResultCount: 2,
                firstSearchResultTitle: "Mikael Vesavuori",
                firstSearchResultURL: "https://mikaelvesavuori.se/",
                requiredText: [
                    "Results 1 to 10 from 137",
                    "Previous results page",
                    "Next results page"
                ],
                forbiddenText: [
                    "Preferences",
                    "Advanced Search",
                    "Brave"
                ]
            ),
            RegressionCase(
                name: "lazy-srcset-figure",
                finalURL: URL(string: "https://example.com/read")!,
                expectedTitle: "Lazy image regression",
                expectedImageURLs: [
                    "https://cdn.example.net/photos/large.jpg"
                ],
                requiredText: [
                    "The story has enough text before the image",
                    "A lazy image."
                ]
            )
        ]

        for testCase in cases {
            try assertRegressionCase(testCase)
        }
    }

    private func assertRegressionCase(_ testCase: RegressionCase, file: StaticString = #filePath, line: UInt = #line) throws {
        let html = try fixture(named: testCase.name)
        let sanitized = try Sanitizer().sanitize(html: html, baseURL: testCase.finalURL)
        let document = try DocumentExtractor().extract(
            sanitizedHTML: sanitized,
            sourceURL: testCase.finalURL,
            finalURL: testCase.finalURL,
            fetchedAt: Date(timeIntervalSince1970: 0)
        )
        let exportedText = DocumentTextExporter().plainText(from: document)

        if let expectedTitle = testCase.expectedTitle {
            XCTAssertEqual(document.title, expectedTitle, testCase.name, file: file, line: line)
        }

        if let expectedSiteName = testCase.expectedSiteName {
            XCTAssertEqual(document.siteName, expectedSiteName, testCase.name, file: file, line: line)
        }

        if let expectedAuthor = testCase.expectedAuthor {
            XCTAssertEqual(document.author, expectedAuthor, testCase.name, file: file, line: line)
        }

        if let expectedHeroImageURL = testCase.expectedHeroImageURL {
            XCTAssertEqual(document.heroImage?.sourceURL.absoluteString, expectedHeroImageURL, testCase.name, file: file, line: line)
        }

        if let expectedImageURLs = testCase.expectedImageURLs {
            XCTAssertEqual(document.images.map(\.sourceURL.absoluteString), expectedImageURLs, testCase.name, file: file, line: line)
        }

        if let expectedSearchResultCount = testCase.expectedSearchResultCount {
            let results = searchResults(in: document)
            XCTAssertEqual(results.count, expectedSearchResultCount, testCase.name, file: file, line: line)

            if let firstTitle = testCase.firstSearchResultTitle {
                XCTAssertEqual(results.first?.title, firstTitle, testCase.name, file: file, line: line)
            }

            if let firstURL = testCase.firstSearchResultURL {
                XCTAssertEqual(results.first?.url.absoluteString, firstURL, testCase.name, file: file, line: line)
            }
        }

        for text in testCase.requiredText {
            XCTAssertTrue(exportedText.contains(text), "\(testCase.name) should contain: \(text)", file: file, line: line)
        }

        for text in testCase.forbiddenText {
            XCTAssertFalse(exportedText.contains(text), "\(testCase.name) should not contain: \(text)", file: file, line: line)
        }

        XCTAssertNotEqual(document.extractionQuality, .weak, testCase.name, file: file, line: line)
    }

    private func fixture(named name: String) throws -> String {
        let url = try XCTUnwrap(
            Bundle.module.url(
                forResource: name,
                withExtension: "html",
                subdirectory: "Fixtures/ExtractionRegression"
            )
        )
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func searchResults(in document: DocumentModel) -> [SearchResult] {
        document.elements.compactMap { element in
            guard case .searchResult(let result) = element else {
                return nil
            }
            return result
        }
    }
}

private struct RegressionCase {
    var name: String
    var finalURL: URL
    var expectedTitle: String?
    var expectedSiteName: String?
    var expectedAuthor: String?
    var expectedHeroImageURL: String?
    var expectedImageURLs: [String]?
    var expectedSearchResultCount: Int?
    var firstSearchResultTitle: String?
    var firstSearchResultURL: String?
    var requiredText: [String]
    var forbiddenText: [String]

    init(
        name: String,
        finalURL: URL,
        expectedTitle: String? = nil,
        expectedSiteName: String? = nil,
        expectedAuthor: String? = nil,
        expectedHeroImageURL: String? = nil,
        expectedImageURLs: [String]? = nil,
        expectedSearchResultCount: Int? = nil,
        firstSearchResultTitle: String? = nil,
        firstSearchResultURL: String? = nil,
        requiredText: [String] = [],
        forbiddenText: [String] = []
    ) {
        self.name = name
        self.finalURL = finalURL
        self.expectedTitle = expectedTitle
        self.expectedSiteName = expectedSiteName
        self.expectedAuthor = expectedAuthor
        self.expectedHeroImageURL = expectedHeroImageURL
        self.expectedImageURLs = expectedImageURLs
        self.expectedSearchResultCount = expectedSearchResultCount
        self.firstSearchResultTitle = firstSearchResultTitle
        self.firstSearchResultURL = firstSearchResultURL
        self.requiredText = requiredText
        self.forbiddenText = forbiddenText
    }
}
