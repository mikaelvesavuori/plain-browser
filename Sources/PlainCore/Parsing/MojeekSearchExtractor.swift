import Foundation
import SwiftSoup

struct MojeekSearchExtractor: Sendable {
    func extract(
        from document: Document,
        sourceURL: URL,
        finalURL: URL,
        fetchedAt: Date
    ) throws -> DocumentModel? {
        guard isMojeekSearchURL(finalURL) else {
            return nil
        }

        let results = try document.select("ul.results-standard > li").array().compactMap { element -> SearchResult? in
            guard let titleLink = try element.select("h2 a.title, a.title").first() else {
                return nil
            }

            let title = normalized(try titleLink.text())
            guard shouldKeepTextBlock(title),
                  let url = try resolvedURL(from: titleLink, attribute: "href", baseURL: finalURL),
                  !isMojeekSearchURL(url) else {
                return nil
            }

            let displayURL = normalized(try element.select("p.i .url, p.i").first()?.text() ?? "")
            let snippet = normalized(try element.select("p.s").first()?.text() ?? "")

            return SearchResult(
                title: title,
                url: url,
                displayURL: displayURL.nilIfEmpty,
                snippet: snippet.nilIfEmpty
            )
        }

        guard !results.isEmpty else {
            return nil
        }

        let query = searchQuery(from: finalURL) ?? "Search"
        let summary = normalized(try document.select(".js-results-cnt-bar p, .results-count-container p").first()?.text() ?? "")
        var elements: [DocumentElement] = []

        if let summary = summary.nilIfEmpty {
            elements.append(.paragraph([.text(summary)]))
        }

        elements.append(contentsOf: results.map(DocumentElement.searchResult))
        appendPaginationLinks(to: &elements, from: document, finalURL: finalURL)

        return DocumentModel(
            sourceURL: sourceURL,
            finalURL: finalURL,
            title: "Search: \(query)",
            siteName: "Mojeek",
            excerpt: summary.nilIfEmpty,
            elements: elements,
            images: [],
            fetchedAt: fetchedAt,
            extractionQuality: .strong
        )
    }

    private func appendPaginationLinks(to elements: inout [DocumentElement], from document: Document, finalURL: URL) {
        let previousPage = try? paginationLink(named: "prev", from: document, finalURL: finalURL)
        let nextPage = try? paginationLink(named: "next", from: document, finalURL: finalURL)

        guard previousPage != nil || nextPage != nil else {
            return
        }

        elements.append(.horizontalRule)
        if let previousPage {
            elements.append(.linkPreview(url: previousPage, text: "Previous results page"))
        }
        if let nextPage {
            elements.append(.linkPreview(url: nextPage, text: "Next results page"))
        }
    }

    private func paginationLink(named label: String, from document: Document, finalURL: URL) throws -> URL? {
        for link in try document.select(".pagination a").array() {
            let text = normalized(try link.text()).lowercased()
            guard text == label else {
                continue
            }

            return try resolvedURL(from: link, attribute: "href", baseURL: finalURL)
        }

        return nil
    }

    private func isMojeekSearchURL(_ url: URL) -> Bool {
        guard let host = url.host(percentEncoded: false)?.lowercased() else {
            return false
        }

        return (host == "www.mojeek.com" || host == "mojeek.com")
            && url.path == "/search"
            && searchQuery(from: url) != nil
    }

    private func searchQuery(from url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: true)?
            .queryItems?
            .first(where: { $0.name == "q" })?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    private func resolvedURL(from element: Element, attribute: String, baseURL: URL) throws -> URL? {
        let rawValue = try element.attr(attribute)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawValue.isEmpty else {
            return nil
        }

        let url = URL(string: rawValue, relativeTo: baseURL)?.absoluteURL
        guard let scheme = url?.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return nil
        }
        return url
    }

    private func shouldKeepTextBlock(_ text: String) -> Bool {
        let normalizedText = normalized(text)
        guard !normalizedText.isEmpty else {
            return false
        }

        return !isLikelyUIChromeText(normalizedText)
    }

    private func isLikelyUIChromeText(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        guard !lowercased.isEmpty else {
            return true
        }

        let chromePhrases = [
            "save this story",
            "share this story",
            "share story",
            "share this article",
            "share article",
            "subscribe",
            "sign in",
            "sign up",
            "read more",
            "advertisement",
            "cookie",
            "cookies"
        ]

        if lowercased.count <= 80,
           chromePhrases.contains(where: { lowercased.contains($0) }) {
            return true
        }

        let words = lowercased
            .split(whereSeparator: \.isWhitespace)
            .map { word in
                word.filter { $0.isLetter || $0.isNumber }
            }
            .filter { !$0.isEmpty }

        if (4...10).contains(words.count) {
            let uniqueWordCount = Set(words).count
            if uniqueWordCount <= Int(ceil(Double(words.count) / 3.0)) {
                return true
            }
        }

        return false
    }

    private func normalized(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
