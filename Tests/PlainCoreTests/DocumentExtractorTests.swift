import Foundation
import PlainCore
import XCTest

final class DocumentExtractorTests: XCTestCase {
    func testExtractorBuildsSemanticDocumentModel() throws {
        let baseURL = URL(string: "https://example.com/read")!
        let html = try fixture(named: "article")
        let sanitized = try Sanitizer().sanitize(html: html, baseURL: baseURL)

        let document = try DocumentExtractor().extract(
            sanitizedHTML: sanitized,
            sourceURL: baseURL,
            finalURL: baseURL,
            fetchedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(document.title, "Plain Test Article")
        XCTAssertEqual(document.siteName, "Example Journal")
        XCTAssertEqual(document.author, "A. Writer")
        XCTAssertEqual(document.extractionQuality, .strong)
        XCTAssertEqual(document.images.first?.sourceURL.absoluteString, "https://example.com/images/plainview.png")

        XCTAssertTrue(document.elements.contains { element in
            if case .heading(1, "Plain Test Article") = element {
                return true
            }
            return false
        })

        XCTAssertTrue(document.elements.contains { element in
            guard case .paragraph(let inline) = element else {
                return false
            }
            return inline.contains(.link(text: "link", url: URL(string: "https://example.com/next?utm_source=x")!))
        })

        XCTAssertTrue(document.elements.contains { element in
            if case .figure(let image, let caption) = element {
                return image.alt == "Reader screenshot" && caption == "A native reader view."
            }
            return false
        })

        XCTAssertTrue(document.elements.contains { element in
            if case .codeBlock("swift", let code) = element {
                return code == "let idea = \"quiet web\""
            }
            return false
        })

        XCTAssertTrue(document.elements.contains { element in
            if case .table(let table) = element {
                return table.headers == ["Phase", "Status"] && table.rows == [["Fetch", "Ready"]]
            }
            return false
        })
    }

    func testExtractorPreservesWhitespaceAroundInlineFormatting() throws {
        let baseURL = URL(string: "https://example.com/read")!
        let html = """
        <!doctype html>
        <article>
          <p>Det är både<strong> gripande</strong> och <em>plågsamt </em>att läsa.</p>
          <p>Pl<strong>ain</strong> should remain one word.</p>
          <p>Continue <a href="/next"> reading</a> today.</p>
          <p>I work at <a href="https://evroc.example.com">evroc</a>. I build <a href="https://molnos.example.com">MolnOS</a>, <strong>Popcorn Cloud</strong>—and <em>Technical Standards Lead</em> at <a href="https://polestar.example.com">Polestar</a>.</p>
          <p>Awkward source spacing: <a href="https://evroc.example.com">evroc </a>. <a href="https://molnos.example.com">MolnOS </a> , and <a href="https://polestar.example.com">Polestar </a> .</p>
        </article>
        """
        let sanitized = try Sanitizer().sanitize(html: html, baseURL: baseURL)

        let document = try DocumentExtractor().extract(
            sanitizedHTML: sanitized,
            sourceURL: baseURL,
            finalURL: baseURL,
            fetchedAt: Date(timeIntervalSince1970: 0)
        )

        let paragraphs = document.elements.compactMap { element -> [InlineElement]? in
            guard case .paragraph(let inline) = element else {
                return nil
            }
            return inline
        }

        XCTAssertEqual(paragraphs.map(plainText), [
            "Det är både gripande och plågsamt att läsa.",
            "Plain should remain one word.",
            "Continue reading today.",
            "I work at evroc. I build MolnOS, Popcorn Cloud—and Technical Standards Lead at Polestar.",
            "Awkward source spacing: evroc. MolnOS, and Polestar."
        ])
    }

    func testExtractorFindsLazyAndSrcsetImages() throws {
        let baseURL = URL(string: "https://example.com/read")!
        let html = """
        <!doctype html>
        <article>
          <figure>
            <img src="data:image/gif;base64,R0lGODlhAQABAAAAACw="
                 data-src="https://cdn.example.net/photos/medium.jpg"
                 data-srcset="https://cdn.example.net/photos/small.jpg 480w, https://cdn.example.net/photos/large.jpg 1280w"
                 alt="Lazy CDN image">
            <figcaption>A lazy image.</figcaption>
          </figure>
        </article>
        """
        let sanitized = try Sanitizer().sanitize(html: html, baseURL: baseURL)

        let document = try DocumentExtractor().extract(
            sanitizedHTML: sanitized,
            sourceURL: baseURL,
            finalURL: baseURL,
            fetchedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(document.images.first?.sourceURL.absoluteString, "https://cdn.example.net/photos/large.jpg")
        XCTAssertEqual(document.images.first?.alt, "Lazy CDN image")
    }

    func testExtractorUsesJsonLDMetadataAndSplitArticleBody() throws {
        let baseURL = URL(string: "https://messy.example.com/story/42")!
        let html = """
        <!doctype html>
        <html>
          <head>
            <title>Messy shell title - Example</title>
            <script type="application/ld+json">
            {
              "@context": "https://schema.org",
              "@type": "NewsArticle",
              "headline": "JSON-LD headline wins",
              "description": "A cleaner summary from structured metadata.",
              "datePublished": "2026-05-14T10:30:00Z",
              "author": [{ "@type": "Person", "name": "Structured Writer" }],
              "publisher": { "@type": "Organization", "name": "Messy Daily" },
              "image": { "url": "/images/story-hero.jpg" }
            }
            </script>
          </head>
          <body>
            <nav><a href="/front">Front page</a><a href="/sports">Sports</a><a href="/culture">Culture</a></nav>
            <div class="layout-shell">
              <div class="newsletter-box">Subscribe to every update from this site</div>
              <div class="story-body">
                <div>The first meaningful paragraph is stored in a plain div because this page was assembled by a client-side publishing system. It still has enough sentence structure to read well.</div>
                <div>The second meaningful paragraph continues the reported story with concrete detail, context, and a useful transition for the reader. It should not be mistaken for navigation.</div>
                <div>The third meaningful paragraph gives Plain enough dense prose to identify this as the article body even without semantic paragraph tags. This is the content worth keeping.</div>
              </div>
              <div class="related-links"><a href="/other">Read more</a><a href="/another">More stories</a></div>
            </div>
          </body>
        </html>
        """
        let sanitized = try Sanitizer().sanitize(html: html, baseURL: baseURL)

        let document = try DocumentExtractor().extract(
            sanitizedHTML: sanitized,
            sourceURL: baseURL,
            finalURL: baseURL,
            fetchedAt: Date(timeIntervalSince1970: 0)
        )

        let exportedText = DocumentTextExporter().plainText(from: document)
        XCTAssertEqual(document.title, "JSON-LD headline wins")
        XCTAssertEqual(document.siteName, "Messy Daily")
        XCTAssertEqual(document.author, "Structured Writer")
        XCTAssertEqual(document.excerpt, "A cleaner summary from structured metadata.")
        XCTAssertEqual(document.heroImage?.sourceURL.absoluteString, "https://messy.example.com/images/story-hero.jpg")
        XCTAssertEqual(document.extractionQuality, .strong)
        XCTAssertTrue(exportedText.contains("first meaningful paragraph"))
        XCTAssertTrue(exportedText.contains("third meaningful paragraph"))
        XCTAssertFalse(exportedText.contains("Subscribe to every update"))
        XCTAssertFalse(exportedText.contains("Read more"))
    }

    func testExtractorPrefersDenseContentOverNavigationHeavyShell() throws {
        let baseURL = URL(string: "https://messy.example.com/read")!
        let html = """
        <!doctype html>
        <html>
          <head><title>Dense content test</title></head>
          <body>
            <div id="app">
              <div class="menu-panel">
                <a href="/1">Politics</a><a href="/2">Business</a><a href="/3">Sports</a>
                <a href="/4">Opinion</a><a href="/5">Style</a><a href="/6">Travel</a>
                <a href="/7">Video</a><a href="/8">Audio</a><a href="/9">Subscribe</a>
              </div>
              <section class="primary-column">
                <div data-component="text-block">This article uses generic containers and removes nearly every useful semantic marker. The prose itself remains readable, detailed, and shaped like a real article paragraph.</div>
                <div data-component="text-block">A second dense paragraph should help Plain avoid choosing the navigation shell just because it has a lot of text and links. The extractor should value prose density over link density.</div>
              </section>
            </div>
          </body>
        </html>
        """
        let sanitized = try Sanitizer().sanitize(html: html, baseURL: baseURL)

        let document = try DocumentExtractor().extract(
            sanitizedHTML: sanitized,
            sourceURL: baseURL,
            finalURL: baseURL,
            fetchedAt: Date(timeIntervalSince1970: 0)
        )

        let exportedText = DocumentTextExporter().plainText(from: document)
        XCTAssertTrue(exportedText.contains("generic containers"))
        XCTAssertTrue(exportedText.contains("prose density over link density"))
        XCTAssertFalse(exportedText.contains("Politics Business Sports"))
        XCTAssertNotEqual(document.extractionQuality, .weak)
    }

    func testExtractorDropsDecorativeVideoFramesFromMarketingPages() throws {
        let baseURL = URL(string: "https://evroc.example.com/")!
        let html = """
        <!doctype html>
        <html>
          <head>
            <title>evroc</title>
            <meta property="og:image" content="/share.jpg">
          </head>
          <body>
            <main>
              <div class="NewLandingPageHero__Header">
                <h1>The European Cloud</h1>
                <h2>A better cloud. Built for AI.</h2>
              </div>
              <div class="NewLandingPageHero__IpadFrameWrapper">
                <img src="/static/ipadframe2.png" class="NewLandingPageHero__IpadFrameImg">
                <div class="VideoPlayer__VideoContainer">
                  <video src="/static/evroc_console_4.mp4" autoplay muted loop playsinline></video>
                </div>
              </div>
              <section class="NewLandingPageHero__CloudServicesContainer">
                <h2>Cloud Services</h2>
                <p>evroc's cloud is built from the ground up, designed to meet tomorrow's demands with secure European infrastructure.</p>
              </section>
              <img src="/static/Cloud_1.png" alt="Cloud 1">
              <img src="/static/arrowButton.png" alt="arrow icon">
            </main>
          </body>
        </html>
        """
        let sanitized = try Sanitizer().sanitize(html: html, baseURL: baseURL)

        let document = try DocumentExtractor().extract(
            sanitizedHTML: sanitized,
            sourceURL: baseURL,
            finalURL: baseURL,
            fetchedAt: Date(timeIntervalSince1970: 0)
        )

        let exportedText = DocumentTextExporter().plainText(from: document)
        XCTAssertTrue(exportedText.contains("The European Cloud"))
        XCTAssertTrue(exportedText.contains("Cloud Services"))
        XCTAssertFalse(exportedText.contains("evroc_console_4.mp4"))
        XCTAssertTrue(document.images.isEmpty)
        XCTAssertEqual(document.heroImage?.sourceURL.absoluteString, "https://evroc.example.com/share.jpg")
    }

    func testExtractorBuildsCleanMojeekSearchResultsDocument() throws {
        let baseURL = URL(string: "https://www.mojeek.com/search?q=mikael%20vesavuori")!
        let html = """
        <!doctype html>
        <html>
          <head><title>mikael vesavuori - Mojeek Search</title></head>
          <body>
            <div class="header">
              <a href="/">Mojeek</a>
              <a href="/preferences">Preferences</a>
              <a href="/advanced.html">Advanced Search</a>
            </div>
            <div class="opts-bar">
              <a href="/search?q=mikael+vesavuori">Web</a>
              <a href="/search?q=mikael+vesavuori&amp;fmt=images">Images</a>
            </div>
            <div class="results-count-container">
              <div class="js-results-cnt-bar"><p>Results 1 to 10 from 137 in 0.07s</p></div>
            </div>
            <ul class="results-standard">
              <li class="r1">
                <a class="ob" href="https://mikaelvesavuori.se/"><p class="i"><span class="url">https://mikaelvesavuori.se/</span></p></a>
                <h2><a class="title" href="https://mikaelvesavuori.se/">Mikael Vesavuori</a></h2>
                <p class="s">My name is Mikael Vesavuori, and I'm a human with an artist's soul.</p>
              </li>
              <li class="r2">
                <a class="ob" href="https://example.com/cloudflare"><p class="i"><span class="url">https://example.com/cloudflare</span></p></a>
                <h2><a class="title" href="https://example.com/cloudflare">Polestar video customer story</a></h2>
                <p class="s">Mikael Vesavuori explains the architecture work.</p>
                <p class="more"><a href="/search?q=site%3Aexample.com+mikael+vesavuori">See more results from example.com</a></p>
              </li>
            </ul>
            <div class="pagination">
              <ul>
                <li><a href="/search?q=mikael+vesavuori">Prev</a></li>
                <li><a href="/search?q=mikael+vesavuori&amp;s=21">Next</a></li>
              </ul>
            </div>
            <div class="scb"><a href="/search?q=mikael+vesavuori&amp;sc=Brave">Brave</a></div>
          </body>
        </html>
        """
        let sanitized = try Sanitizer().sanitize(html: html, baseURL: baseURL)

        let document = try DocumentExtractor().extract(
            sanitizedHTML: sanitized,
            sourceURL: baseURL,
            finalURL: baseURL,
            fetchedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(document.title, "Search: mikael vesavuori")
        XCTAssertEqual(document.siteName, "Mojeek")
        XCTAssertEqual(document.extractionQuality, .strong)

        let results = document.elements.compactMap { element -> SearchResult? in
            guard case .searchResult(let result) = element else {
                return nil
            }
            return result
        }

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.first?.title, "Mikael Vesavuori")
        XCTAssertEqual(results.first?.url.absoluteString, "https://mikaelvesavuori.se/")
        XCTAssertEqual(results.first?.snippet, "My name is Mikael Vesavuori, and I'm a human with an artist's soul.")

        let exportedText = DocumentTextExporter().plainText(from: document)
        XCTAssertTrue(exportedText.contains("Results 1 to 10 from 137"))
        XCTAssertTrue(exportedText.contains("Previous results page"))
        XCTAssertTrue(exportedText.contains("Next results page"))
        XCTAssertFalse(exportedText.contains("Preferences"))
        XCTAssertFalse(exportedText.contains("Advanced Search"))
        XCTAssertFalse(exportedText.contains("Brave"))
    }

    private func fixture(named name: String) throws -> String {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "html", subdirectory: "Fixtures"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func plainText(from inline: [InlineElement]) -> String {
        inline.map { element in
            switch element {
            case .text(let text), .strong(let text), .emphasis(let text), .code(let text):
                return text
            case .link(let text, _):
                return text
            case .lineBreak:
                return "\n"
            }
        }
        .joined()
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
