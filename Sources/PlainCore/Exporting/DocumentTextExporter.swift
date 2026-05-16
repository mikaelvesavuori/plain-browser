import Foundation

public struct DocumentTextExporter: Sendable {
    public init() {}

    public func plainText(from document: DocumentModel) -> String {
        var lines: [String] = []

        if let title = document.title {
            lines.append(title)
            lines.append("")
        }

        for element in document.elements {
            appendPlainText(for: element, to: &lines)
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func markdown(from document: DocumentModel) -> String {
        var lines: [String] = []

        if let title = document.title {
            lines.append("# \(title)")
            lines.append("")
        }

        for element in document.elements {
            appendMarkdown(for: element, to: &lines)
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func appendPlainText(for element: DocumentElement, to lines: inout [String]) {
        switch element {
        case .heading(_, let text):
            lines.append(text)
            lines.append("")
        case .paragraph(let inline):
            lines.append(plainText(from: inline))
            lines.append("")
        case .searchResult(let result):
            lines.append(result.title)
            lines.append(result.url.absoluteString)
            if let snippet = result.snippet {
                lines.append(snippet)
            }
            lines.append("")
        case .image(let image):
            if let alt = image.alt {
                lines.append("[Image: \(alt)]")
                lines.append("")
            }
        case .figure(let image, let caption):
            let text = caption ?? image.caption ?? image.alt
            if let text {
                lines.append("[Image: \(text)]")
                lines.append("")
            }
        case .blockquote(let elements):
            for child in elements {
                appendPlainText(for: child, to: &lines)
            }
        case .list(let ordered, let items):
            for (index, item) in items.enumerated() {
                let prefix = ordered ? "\(index + 1). " : "- "
                let text = item.map(plainTextForNestedElement).joined(separator: " ")
                lines.append(prefix + text)
            }
            lines.append("")
        case .codeBlock(_, let code):
            lines.append(code)
            lines.append("")
        case .table(let table):
            if !table.headers.isEmpty {
                lines.append(table.headers.joined(separator: "\t"))
            }
            for row in table.rows {
                lines.append(row.joined(separator: "\t"))
            }
            lines.append("")
        case .horizontalRule:
            lines.append("")
        case .linkPreview(let url, let text):
            lines.append(text.map { "\($0): \(url.absoluteString)" } ?? url.absoluteString)
            lines.append("")
        }
    }

    private func appendMarkdown(for element: DocumentElement, to lines: inout [String]) {
        switch element {
        case .heading(let level, let text):
            lines.append("\(String(repeating: "#", count: max(1, min(level, 6)))) \(text)")
            lines.append("")
        case .paragraph(let inline):
            lines.append(markdown(from: inline))
            lines.append("")
        case .searchResult(let result):
            lines.append("## [\(result.title)](\(result.url.absoluteString))")
            if let displayURL = result.displayURL {
                lines.append("")
                lines.append("`\(displayURL)`")
            }
            if let snippet = result.snippet {
                lines.append("")
                lines.append(snippet)
            }
            lines.append("")
        case .image(let image):
            lines.append("![\(image.alt ?? "Image")](\(image.sourceURL.absoluteString))")
            lines.append("")
        case .figure(let image, let caption):
            lines.append("![\(image.alt ?? caption ?? "Image")](\(image.sourceURL.absoluteString))")
            if let caption = caption ?? image.caption {
                lines.append("")
                lines.append("_\(caption)_")
            }
            lines.append("")
        case .blockquote(let elements):
            let text = elements.map(markdownForNestedElement).joined(separator: "\n")
            for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                lines.append("> \(line)")
            }
            lines.append("")
        case .list(let ordered, let items):
            for (index, item) in items.enumerated() {
                let prefix = ordered ? "\(index + 1). " : "- "
                lines.append(prefix + item.map(markdownForNestedElement).joined(separator: " "))
            }
            lines.append("")
        case .codeBlock(let language, let code):
            lines.append("```\(language ?? "")")
            lines.append(code)
            lines.append("```")
            lines.append("")
        case .table(let table):
            if !table.headers.isEmpty {
                lines.append("| \(table.headers.joined(separator: " | ")) |")
                lines.append("| \(table.headers.map { _ in "---" }.joined(separator: " | ")) |")
            }
            for row in table.rows {
                lines.append("| \(row.joined(separator: " | ")) |")
            }
            lines.append("")
        case .horizontalRule:
            lines.append("---")
            lines.append("")
        case .linkPreview(let url, let text):
            lines.append("[\(text ?? url.absoluteString)](\(url.absoluteString))")
            lines.append("")
        }
    }

    private func plainTextForNestedElement(_ element: DocumentElement) -> String {
        switch element {
        case .paragraph(let inline):
            return plainText(from: inline)
        case .heading(_, let text):
            return text
        default:
            var lines: [String] = []
            appendPlainText(for: element, to: &lines)
            return lines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func markdownForNestedElement(_ element: DocumentElement) -> String {
        switch element {
        case .paragraph(let inline):
            return markdown(from: inline)
        case .heading(_, let text):
            return text
        default:
            var lines: [String] = []
            appendMarkdown(for: element, to: &lines)
            return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
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

    private func markdown(from inline: [InlineElement]) -> String {
        inline.map { element in
            switch element {
            case .text(let text):
                return text
            case .strong(let text):
                return "**\(text)**"
            case .emphasis(let text):
                return "_\(text)_"
            case .code(let text):
                return "`\(text)`"
            case .link(let text, let url):
                return "[\(text)](\(url.absoluteString))"
            case .lineBreak:
                return "\n"
            }
        }
        .joined()
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
