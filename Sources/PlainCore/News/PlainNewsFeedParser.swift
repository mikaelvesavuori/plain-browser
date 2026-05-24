import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

public struct PlainNewsFeedItem: Equatable, Sendable {
    public var title: String
    public var url: URL?
    public var publishedAt: Date?
    public var summary: String

    public init(title: String, url: URL?, publishedAt: Date?, summary: String) {
        self.title = title
        self.url = url
        self.publishedAt = publishedAt
        self.summary = summary
    }
}

public struct PlainNewsFeedParser: Sendable {
    public init() {}

    public func parse(_ data: Data, sourceURL: URL) throws -> [PlainNewsFeedItem] {
        let delegate = FeedParserDelegate(sourceURL: sourceURL)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false

        guard parser.parse() else {
            throw PlainError.decodeFailed
        }

        return delegate.items
    }
}

private final class FeedParserDelegate: NSObject, XMLParserDelegate {
    private struct MutableItem {
        var title = ""
        var link = ""
        var publishedAt = ""
        var summary = ""
    }

    private let sourceURL: URL
    private var currentItem: MutableItem?
    private var currentElement = ""
    private var currentText = ""
    private var isInsideItem = false
    private(set) var items: [PlainNewsFeedItem] = []

    init(sourceURL: URL) {
        self.sourceURL = sourceURL
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let name = normalizedElementName(elementName)
        currentElement = name
        currentText = ""

        if name == "item" || name == "entry" {
            isInsideItem = true
            currentItem = MutableItem()
            return
        }

        guard isInsideItem, name == "link" else {
            return
        }

        if let href = attributeDict["href"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !href.isEmpty {
            currentItem?.link = href
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInsideItem else {
            return
        }
        currentText += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard isInsideItem,
              let string = String(data: CDATABlock, encoding: .utf8) else {
            return
        }
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = normalizedElementName(elementName)

        guard isInsideItem else {
            return
        }

        if name == "item" || name == "entry" {
            appendCurrentItem()
            currentItem = nil
            currentText = ""
            currentElement = ""
            isInsideItem = false
            return
        }

        let value = normalizedText(currentText)
        guard !value.isEmpty else {
            currentText = ""
            return
        }

        guard var item = currentItem else {
            currentText = ""
            return
        }

        switch name {
        case "title":
            item.title += separated(existing: item.title, next: value)
        case "link", "id":
            if item.link.isEmpty {
                item.link = value
            }
        case "pubdate", "published", "updated", "date":
            if item.publishedAt.isEmpty {
                item.publishedAt = value
            }
        case "description", "summary", "content", "encoded":
            item.summary += separated(existing: item.summary, next: value)
        default:
            break
        }

        currentItem = item

        currentText = ""
    }

    private func appendCurrentItem() {
        guard let currentItem else {
            return
        }

        let title = normalizedText(currentItem.title)
        let summary = normalizedText(stripHTML(currentItem.summary))
        let url = URL(string: currentItem.link, relativeTo: sourceURL)?.absoluteURL
        guard !title.isEmpty || url != nil else {
            return
        }

        items.append(PlainNewsFeedItem(
            title: title.isEmpty ? url?.absoluteString ?? "Untitled" : title,
            url: url,
            publishedAt: parseFeedDate(currentItem.publishedAt),
            summary: summary
        ))
    }

    private func normalizedElementName(_ value: String) -> String {
        value
            .lowercased()
            .split(separator: ":")
            .last
            .map(String.init) ?? value.lowercased()
    }

    private func normalizedText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func separated(existing: String, next: String) -> String {
        existing.isEmpty ? next : "\(existing) \(next)"
    }

    private func stripHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }

    private func parseFeedDate(_ value: String) -> Date? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return nil
        }

        for formatter in ISO8601DateFormatter.plainNewsFeedFormatters() {
            if let date = formatter.date(from: normalized) {
                return date
            }
        }

        for formatter in DateFormatter.plainNewsFeedFormatters() {
            if let date = formatter.date(from: normalized) {
                return date
            }
        }

        return nil
    }
}

private extension ISO8601DateFormatter {
    static func plainNewsFeedFormatters() -> [ISO8601DateFormatter] {
        let internet = ISO8601DateFormatter()
        internet.formatOptions = [.withInternetDateTime]

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return [internet, formatter]
    }
}

private extension DateFormatter {
    static func plainNewsFeedFormatters() -> [DateFormatter] {
        [
            makePlainNewsFormatter("EEE, d MMM yyyy HH:mm:ss Z"),
            makePlainNewsFormatter("EEE, dd MMM yyyy HH:mm:ss Z"),
            makePlainNewsFormatter("d MMM yyyy HH:mm:ss Z"),
            makePlainNewsFormatter("yyyy-MM-dd'T'HH:mm:ssZ"),
            makePlainNewsFormatter("yyyy-MM-dd")
        ]
    }

    static func makePlainNewsFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = format
        return formatter
    }
}
