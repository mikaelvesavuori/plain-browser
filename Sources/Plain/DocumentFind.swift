import Foundation
import PlainCore

enum DocumentFindTarget: Hashable {
    case header
    case element(Int)
}

struct DocumentFindMatch: Identifiable {
    var id: Int
    var target: DocumentFindTarget
}

struct DocumentFindIndex {
    var query: String
    var matches: [DocumentFindMatch]

    init(document: DocumentModel?, query rawQuery: String) {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        self.query = query

        guard let document, !query.isEmpty else {
            matches = []
            return
        }

        var nextID = 0
        var values: [DocumentFindMatch] = []

        func appendMatches(target: DocumentFindTarget, text: String) {
            let count = Self.matchCount(in: text, query: query)
            guard count > 0 else {
                return
            }

            for _ in 0..<count {
                values.append(DocumentFindMatch(id: nextID, target: target))
                nextID += 1
            }
        }

        appendMatches(
            target: .header,
            text: [
                document.finalURL.host(percentEncoded: false),
                document.siteName,
                document.author,
                document.title,
                document.excerpt
            ]
            .compactMap { $0 }
            .joined(separator: "\n")
        )

        for (index, element) in document.elements.enumerated() {
            appendMatches(target: .element(index), text: element.findableText)
        }

        matches = values
    }

    private static func matchCount(in text: String, query: String) -> Int {
        guard !text.isEmpty else {
            return 0
        }

        var count = 0
        var searchRange = text.startIndex..<text.endIndex
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

        while let range = text.range(of: query, options: options, range: searchRange) {
            count += 1
            searchRange = range.upperBound..<text.endIndex
        }

        return count
    }
}

private extension DocumentElement {
    var findableText: String {
        switch self {
        case .heading(_, let text):
            return text
        case .paragraph(let inline):
            return inline.findableText
        case .searchResult(let result):
            return [
                result.displayURL,
                result.title,
                result.snippet,
                result.url.absoluteString
            ]
            .compactMap { $0 }
            .joined(separator: "\n")
        case .image(let image):
            return image.findableText
        case .figure(let image, let caption):
            return [image.findableText, caption]
                .compactMap { $0 }
                .joined(separator: "\n")
        case .blockquote(let elements):
            return elements.map(\.findableText).joined(separator: "\n")
        case .list(_, let items):
            return items
                .flatMap { $0 }
                .map(\.findableText)
                .joined(separator: "\n")
        case .codeBlock(_, let code):
            return code
        case .table(let table):
            return (table.headers + table.rows.flatMap { $0 }).joined(separator: "\n")
        case .horizontalRule:
            return ""
        case .linkPreview(let url, let text):
            return [text, url.absoluteString]
                .compactMap { $0 }
                .joined(separator: "\n")
        }
    }
}

private extension Array where Element == InlineElement {
    var findableText: String {
        map(\.findableText).joined()
    }
}

private extension InlineElement {
    var findableText: String {
        switch self {
        case .text(let text),
             .strong(let text),
             .emphasis(let text),
             .code(let text):
            return text
        case .link(let text, _):
            return text
        case .lineBreak:
            return "\n"
        }
    }
}

private extension ImageRef {
    var findableText: String {
        [alt, caption, sourceURL.absoluteString]
            .compactMap { $0 }
            .joined(separator: "\n")
    }
}
