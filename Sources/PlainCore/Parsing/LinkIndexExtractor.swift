import Foundation
import SwiftSoup

struct LinkIndexExtractor: Sendable {
    func extract(
        from document: Document,
        sourceURL: URL,
        finalURL: URL,
        fetchedAt: Date
    ) throws -> DocumentModel? {
        let results = try linkResults(from: document, finalURL: finalURL)
        guard results.count >= 4,
              try isLikelyLinkIndex(document, results: results) else {
            return nil
        }

        let title = normalized(try document.title()).nilIfEmpty
        return DocumentModel(
            sourceURL: sourceURL,
            finalURL: finalURL,
            title: title ?? "Links from \(finalURL.host(percentEncoded: false) ?? finalURL.absoluteString)",
            siteName: siteName(documentTitle: title, finalURL: finalURL),
            elements: results.map(DocumentElement.searchResult),
            images: [],
            fetchedAt: fetchedAt,
            extractionQuality: .strong
        )
    }

    private func linkResults(from document: Document, finalURL: URL) throws -> [SearchResult] {
        let rows = try document.select([
            "tr.athing",
            "li",
            "article",
            "[class*=result]",
            "[class*=Result]",
            "[class*=item]",
            "[class*=Item]",
            "[class*=card]",
            "[class*=Card]"
        ].joined(separator: ",")).array()

        var seen = Set<URL>()
        var results: [SearchResult] = []

        for row in rows {
            guard let link = try primaryLink(in: row),
                  let url = try resolvedURL(from: link, attribute: "href", baseURL: finalURL),
                  url != finalURL else {
                continue
            }

            let title = normalized(try link.text())
            guard shouldKeepLinkTitle(title), !seen.contains(url) else {
                continue
            }

            seen.insert(url)
            results.append(SearchResult(
                title: title,
                url: url,
                displayURL: url.host(percentEncoded: false)
            ))
        }

        return results
    }

    private func primaryLink(in element: Element) throws -> Element? {
        for selector in [
            ".titleline > a",
            "a.storylink",
            "h1 a[href]",
            "h2 a[href]",
            "h3 a[href]",
            "[class*=title] a[href]",
            "[class*=Title] a[href]",
            "a[href]"
        ] {
            if let link = try element.select(selector).first() {
                return link
            }
        }

        return nil
    }

    private func isLikelyLinkIndex(_ document: Document, results: [SearchResult]) throws -> Bool {
        let body = document.body()
        let bodyText = normalized(try body?.text() ?? "")
        guard !bodyText.isEmpty else {
            return false
        }

        let links = try body?.select("a").array() ?? []
        let linkTextLength = try links.reduce(0) { total, link in
            total + normalized(try link.text()).count
        }
        let linkDensity = Double(linkTextLength) / Double(max(bodyText.count, 1))
        let paragraphCount = try body?.select("p").array().count ?? 0
        let rankedTableRowCount = try document.select("tr.athing").array().count

        if rankedTableRowCount >= 4 {
            return true
        }

        return linkDensity >= 0.55
            && paragraphCount <= max(3, results.count / 2)
            && results.count >= 5
    }

    private func shouldKeepLinkTitle(_ title: String) -> Bool {
        guard (8...180).contains(title.count) else {
            return false
        }

        let lowercased = title.lowercased()
        let chromePhrases = [
            "advertisement",
            "all jobs",
            "comments",
            "cookie",
            "log in",
            "login",
            "menu",
            "next",
            "previous",
            "privacy",
            "read more",
            "sign in",
            "sign up",
            "subscribe"
        ]

        return !chromePhrases.contains { lowercased == $0 || lowercased.contains($0) && title.count <= 40 }
    }

    private func siteName(documentTitle: String?, finalURL: URL) -> String? {
        if let documentTitle,
           !documentTitle.contains(" - "),
           !documentTitle.contains(" | "),
           documentTitle.count <= 60 {
            return documentTitle
        }

        return finalURL.host(percentEncoded: false)
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
