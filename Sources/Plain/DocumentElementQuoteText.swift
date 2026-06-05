import Foundation
import PlainCore

extension DocumentElement {
    var quotePlainText: String? {
        let text: String

        switch self {
        case .heading(_, let value):
            text = value
        case .paragraph(let inline):
            text = inline.quotePlainText
        case .blockquote(let elements):
            text = elements
                .compactMap(\.quotePlainText)
                .joined(separator: "\n\n")
        case .list(let ordered, let items):
            text = items.enumerated()
                .map { index, item in
                    let prefix = ordered ? "\(index + 1). " : "- "
                    return prefix + item.compactMap(\.quotePlainText).joined(separator: " ")
                }
                .joined(separator: "\n")
        case .codeBlock(_, let code):
            text = code
        case .table(let table):
            var rows: [String] = []
            if !table.headers.isEmpty {
                rows.append(table.headers.joined(separator: "\t"))
            }
            rows.append(contentsOf: table.rows.map { $0.joined(separator: "\t") })
            text = rows.joined(separator: "\n")
        case .linkPreview(let url, let label):
            text = label.map { "\($0): \(url.absoluteString)" } ?? url.absoluteString
        case .searchResult, .image, .figure, .horizontalRule:
            return nil
        }

        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}

private extension Array where Element == InlineElement {
    var quotePlainText: String {
        map { element in
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
