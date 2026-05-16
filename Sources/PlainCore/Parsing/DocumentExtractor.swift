import Foundation
import SwiftSoup

public struct DocumentExtractor: Sendable {
    public init() {}

    public func extract(
        sanitizedHTML: SanitizedHTML,
        sourceURL: URL,
        finalURL: URL,
        fetchedAt: Date
    ) throws -> DocumentModel {
        let document = try SwiftSoup.parse(sanitizedHTML.html, finalURL.absoluteString)
        let metadata = try Metadata(document: document, finalURL: finalURL)

        if let searchResults = try MojeekSearchExtractor().extract(
            from: document,
            sourceURL: sourceURL,
            finalURL: finalURL,
            fetchedAt: fetchedAt
        ) {
            return searchResults
        }

        if let linkIndex = try LinkIndexExtractor().extract(
            from: document,
            sourceURL: sourceURL,
            finalURL: finalURL,
            fetchedAt: fetchedAt
        ) {
            return linkIndex
        }

        let selection = try selectMainContent(in: document)

        try removeReaderClutter(from: selection.element)

        var elements = try extractBlockChildren(from: selection.element, baseURL: finalURL)
        elements = elements.removingAdjacentDuplicateHeadings()

        if elements.isEmpty, let body = document.body() {
            try removeReaderClutter(from: body)
            elements = try extractBlockChildren(from: body, baseURL: finalURL)
        }

        guard !elements.isEmpty else {
            throw PlainError.extractionFailed
        }

        let images = collectImages(from: elements)
        let title = metadata.title ?? firstHeading(in: elements)

        return DocumentModel(
            sourceURL: sourceURL,
            finalURL: finalURL,
            title: title,
            siteName: metadata.siteName,
            author: metadata.author,
            publishedAt: metadata.publishedAt,
            excerpt: metadata.excerpt,
            heroImage: metadata.heroImage,
            elements: elements,
            images: images,
            fetchedAt: fetchedAt,
            extractionQuality: selection.quality
        )
    }

    private func selectMainContent(in document: Document) throws -> (element: Element, quality: ExtractionQuality) {
        let preferredSelectors = [
            "article",
            "main",
            "[role=main]",
            "[itemprop=articleBody]",
            "[itemtype*=Article]",
            ".article",
            ".article-content",
            ".post",
            ".post-content",
            ".entry-content",
            ".article-body",
            ".article__body",
            ".story",
            ".story-body",
            ".story__body",
            ".content",
            ".main-content",
            ".page-content",
            "#content",
            "#main-content"
        ].joined(separator: ",")

        var candidates = try document.select(preferredSelectors).array()

        if let body = document.body() {
            candidates.append(body)
            candidates.append(contentsOf: try body.select("section,div").array().filter { element in
                try readableMetrics(for: element).textLength >= 220
            })
        }

        let uniqueCandidates = candidates.removingDuplicateElements()
        let scored = try uniqueCandidates
            .map { try ContentCandidate(element: $0, metrics: readableMetrics(for: $0)) }
            .filter { $0.metrics.textLength >= 160 || $0.metrics.imageCount > 0 }

        if let best = scored.max(by: { $0.score < $1.score }) {
            return (best.element, quality(for: best))
        }

        return (document, .weak)
    }

    private func readableMetrics(for element: Element) throws -> ReadableMetrics {
        let text = normalized(try element.text())
        let textLength = text.count
        let paragraphCount = try element.select("p").array().count
        let imageCount = try element.select("img").array().count
        let linkTextLength = try element.select("a").array().reduce(0) { total, link in
            total + normalized(try link.text()).count
        }
        let headingCount = try element.select("h1,h2,h3").array().count
        let listItemCount = try element.select("li").array().count
        let sentenceCount = text.components(separatedBy: CharacterSet(charactersIn: ".!?。！？"))
            .map { normalized($0) }
            .filter { $0.count >= 30 }
            .count

        let hints = [
            element.tagName(),
            element.id(),
            try element.classNames().joined(separator: " "),
            try element.attr("role"),
            try element.attr("itemprop"),
            try element.attr("itemtype")
        ]
        .joined(separator: " ")
        .lowercased()

        let linkDensity = textLength > 0 ? Double(linkTextLength) / Double(textLength) : 0
        return ReadableMetrics(
            textLength: textLength,
            paragraphCount: paragraphCount,
            imageCount: imageCount,
            headingCount: headingCount,
            listItemCount: listItemCount,
            sentenceCount: sentenceCount,
            linkDensity: linkDensity,
            hints: hints
        )
    }

    private func quality(for candidate: ContentCandidate) -> ExtractionQuality {
        let metrics = candidate.metrics
        let hasSemanticArticleSignal = ContentCandidate.hasGoodHint(metrics.hints)
            && (metrics.hints.contains("article") || metrics.hints.contains("main") || metrics.hints.contains("entry"))

        if hasSemanticArticleSignal,
           candidate.score >= 180,
           metrics.textLength >= 120,
           metrics.linkDensity < 0.45,
           metrics.paragraphCount >= 1 || metrics.sentenceCount >= 2 {
            return .strong
        }

        if candidate.score >= 700,
           metrics.textLength >= 420,
           metrics.linkDensity < 0.45,
           metrics.paragraphCount >= 2 || metrics.sentenceCount >= 4 {
            return .strong
        }

        if candidate.score >= 260,
           metrics.textLength >= 220,
           metrics.linkDensity < 0.6 {
            return .fallback
        }

        return .weak
    }

    private func removeReaderClutter(from element: Element) throws {
        let selectors = [
            "script",
            "nav",
            "header",
            "footer",
            "aside",
            "[role=navigation]",
            "[role=banner]",
            "[role=contentinfo]",
            "[role=complementary]",
            "[class*=advert]",
            "[class*=ad-]",
            "[class*=ads]",
            "[class*=banner]",
            "[class*=breadcrumb]",
            "[class*=comment]",
            "[class*=cookie]",
            "[class*=newsletter]",
            "[class*=promo]",
            "[class*=related]",
            "[class*=share]",
            "[class*=sidebar]",
            "[id*=advert]",
            "[id*=comments]",
            "[id*=newsletter]",
            "[id*=related]",
            "[id*=share]",
            "[id*=sidebar]"
        ].joined(separator: ",")

        try element.select(selectors).remove()
    }

    private func extractBlockChildren(from element: Element, baseURL: URL) throws -> [DocumentElement] {
        var elements: [DocumentElement] = []

        for child in element.children().array() {
            elements.append(contentsOf: try extractBlock(from: child, baseURL: baseURL))
        }

        return elements
    }

    private func extractBlock(from element: Element, baseURL: URL) throws -> [DocumentElement] {
        let tag = element.tagName().lowercased()

        if tag.matchesHeadingTag {
            let text = normalized(try element.text())
            guard shouldKeepTextBlock(text) else { return [] }
            return [.heading(level: tag.headingLevel, text: text)]
        }

        switch tag {
        case "p":
            let inline = try extractInlineChildren(from: element, baseURL: baseURL).trimmed()
            return shouldKeepInline(inline) ? [.paragraph(inline)] : []
        case "img", "picture":
            guard let image = try imageRef(from: element, baseURL: baseURL) else { return [] }
            return [.image(image)]
        case "figure":
            if let image = try figureImage(from: element, baseURL: baseURL) {
                return [.figure(image: image, caption: image.caption)]
            }
            return try extractBlockChildren(from: element, baseURL: baseURL)
        case "blockquote":
            let blocks = try extractBlockChildren(from: element, baseURL: baseURL)
            if !blocks.isEmpty {
                return [.blockquote(blocks)]
            }
            let inline = try extractInlineChildren(from: element, baseURL: baseURL).trimmed()
            return shouldKeepInline(inline) ? [.blockquote([.paragraph(inline)])] : []
        case "ul", "ol":
            let items = try element.children().array()
                .filter { $0.tagName().lowercased() == "li" }
                .compactMap { item -> [DocumentElement]? in
                    let blocks = try extractBlockChildren(from: item, baseURL: baseURL)
                    if !blocks.isEmpty {
                        return blocks
                    }
                    let inline = try extractInlineChildren(from: item, baseURL: baseURL).trimmed()
                    return shouldKeepInline(inline) ? [.paragraph(inline)] : nil
                }
            return items.isEmpty ? [] : [.list(ordered: tag == "ol", items: items)]
        case "pre":
            let codeElement = try element.select("code").first()
            let code = try normalizedPreservingLines(codeElement?.text() ?? element.text())
            guard !code.isEmpty else { return [] }
            return [.codeBlock(language: try codeElement.flatMap(language(from:)), code: code)]
        case "table":
            guard let table = try simpleTable(from: element), !table.rows.isEmpty else { return [] }
            return [.table(table)]
        case "hr":
            return [.horizontalRule]
        case "a":
            guard let url = try resolvedURL(from: element, attribute: "href", baseURL: baseURL) else {
                return []
            }
            let text = normalized(try element.text())
            guard text.isEmpty || shouldKeepTextBlock(text) else { return [] }
            return [.linkPreview(url: url, text: text.isEmpty ? nil : text)]
        case "div", "section", "article", "main", "body", "li", "dd", "dt":
            let blocks = try extractBlockChildren(from: element, baseURL: baseURL)
            if !blocks.isEmpty {
                return blocks
            }
            let inline = try extractInlineChildren(from: element, baseURL: baseURL).trimmed()
            return shouldKeepInline(inline) ? [.paragraph(inline)] : []
        default:
            if element.children().array().isEmpty {
                let inline = try extractInlineChildren(from: element, baseURL: baseURL).trimmed()
                return shouldKeepInline(inline) ? [.paragraph(inline)] : []
            }
            return try extractBlockChildren(from: element, baseURL: baseURL)
        }
    }

    private func extractInlineChildren(from element: Element, baseURL: URL) throws -> [InlineElement] {
        var inline: [InlineElement] = []

        for node in element.getChildNodes() {
            inline.append(contentsOf: try extractInline(from: node, baseURL: baseURL))
        }

        let renderedText = normalizedInline(try plainTextPreservingTagBoundaries(fromHTML: element.html()))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return inline
            .mergedTextRuns()
            .repairingSpacing(matching: renderedText)
            .collapsingDuplicateBoundaryWhitespace()
            .removingSpacesBeforePunctuation()
    }

    private func extractInline(from node: Node, baseURL: URL) throws -> [InlineElement] {
        if let textNode = node as? TextNode {
            let text = normalizedInline(textNode.text())
            return text.isEmpty ? [] : [.text(text)]
        }

        guard let element = node as? Element else {
            return []
        }

        let tag = element.tagName().lowercased()
        switch tag {
        case "br":
            return [.lineBreak]
        case "strong", "b":
            let text = normalizedInline(try element.text(trimAndNormaliseWhitespace: false))
            return text.isEmpty ? [] : [.strong(text)]
        case "em", "i":
            let text = normalizedInline(try element.text(trimAndNormaliseWhitespace: false))
            return text.isEmpty ? [] : [.emphasis(text)]
        case "code":
            let text = normalizedInline(try element.text(trimAndNormaliseWhitespace: false))
            return text.isEmpty ? [] : [.code(text)]
        case "a":
            let text = normalizedInline(try element.text(trimAndNormaliseWhitespace: false))
            guard !text.isEmpty else { return [] }
            if let url = try resolvedURL(from: element, attribute: "href", baseURL: baseURL) {
                return [.link(text: text, url: url)]
            }
            return [.text(text)]
        case "img":
            let alt = normalized(try element.attr("alt"))
            return alt.isEmpty ? [] : [.text(alt)]
        default:
            return try extractInlineChildren(from: element, baseURL: baseURL)
        }
    }

    private func imageRef(from element: Element, baseURL: URL) throws -> ImageRef? {
        let imageElement: Element
        if element.tagName().lowercased() == "picture" {
            guard let nested = try element.select("img").first() else {
                return nil
            }
            imageElement = nested
        } else {
            imageElement = element
        }

        let candidates = try imageURLCandidates(from: imageElement)

        guard let sourceURL = candidates
            .compactMap({ resolve($0, baseURL: baseURL) })
            .first(where: { $0.scheme == "http" || $0.scheme == "https" }) else {
            return nil
        }

        let width = Int(try imageElement.attr("width"))
        let height = Int(try imageElement.attr("height"))
        let alt = normalized(try imageElement.attr("alt")).nilIfEmpty
        guard try shouldKeepImage(
            imageElement,
            sourceURL: sourceURL,
            alt: alt,
            width: width,
            height: height
        ) else {
            return nil
        }

        return ImageRef(
            sourceURL: sourceURL,
            alt: alt,
            width: width,
            height: height,
            mimeType: nil
        )
    }

    private func imageURLCandidates(from imageElement: Element) throws -> [String] {
        var candidates: [String] = []

        for attribute in [
            "srcset",
            "data-srcset",
            "data-lazy-srcset",
            "data-original-srcset",
            "data-zoom-srcset"
        ] {
            candidates.append(contentsOf: srcsetCandidates(from: try imageElement.attr(attribute)))
        }

        for attribute in [
            "data-src",
            "data-original",
            "data-lazy-src",
            "data-zoom-src",
            "data-hi-res-src",
            "src"
        ] {
            candidates.append(try imageElement.attr(attribute))
        }

        if let picture = imageElement.parent(),
           picture.tagName().lowercased() == "picture" {
            for source in try picture.select("source").array() {
                let type = try source.attr("type").lowercased()
                if type.contains("avif") {
                    continue
                }

                candidates.append(contentsOf: srcsetCandidates(from: try source.attr("srcset")))
                candidates.append(contentsOf: srcsetCandidates(from: try source.attr("data-srcset")))
            }
        }

        return candidates
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.lowercased().hasPrefix("data:") }
            .removingDuplicateStrings()
    }

    private func srcsetCandidates(from value: String) -> [String] {
        value
            .split(separator: ",")
            .compactMap { entry -> (url: String, score: Double)? in
                let parts = entry
                    .split(whereSeparator: \.isWhitespace)
                    .map(String.init)
                guard let rawURL = parts.first else {
                    return nil
                }

                let descriptor = parts.dropFirst().first ?? "1x"
                let score: Double
                if descriptor.hasSuffix("w") {
                    score = Double(descriptor.dropLast()) ?? 0
                } else if descriptor.hasSuffix("x") {
                    score = (Double(descriptor.dropLast()) ?? 1) * 1000
                } else {
                    score = 1
                }

                return (rawURL, score)
            }
            .sorted { $0.score > $1.score }
            .map(\.url)
    }

    private func figureImage(from element: Element, baseURL: URL) throws -> ImageRef? {
        guard let imageElement = try element.select("img,picture").first(),
              var image = try imageRef(from: imageElement, baseURL: baseURL) else {
            return nil
        }

        let caption = normalized(try element.select("figcaption").first()?.text() ?? "")
        image.caption = caption.nilIfEmpty
        return image
    }

    private func simpleTable(from element: Element) throws -> SimpleTable? {
        let rows = try element.select("tr").array()
        guard !rows.isEmpty else {
            return nil
        }

        var headers: [String] = []
        var bodyRows: [[String]] = []

        for (index, row) in rows.enumerated() {
            let headerCells = try row.select("th").array()
            let dataCells = try row.select("td").array()

            if !headerCells.isEmpty && index == 0 {
                headers = try headerCells.map { normalized(try $0.text()) }
                if !dataCells.isEmpty {
                    bodyRows.append(try dataCells.map { normalized(try $0.text()) })
                }
            } else {
                let cells = try (dataCells.isEmpty ? headerCells : dataCells).map { normalized(try $0.text()) }
                if !cells.allSatisfy(\.isEmpty) {
                    bodyRows.append(cells)
                }
            }
        }

        return SimpleTable(headers: headers, rows: bodyRows)
    }

    private func language(from element: Element) throws -> String? {
        for className in try element.classNames() {
            if className.hasPrefix("language-") {
                return String(className.dropFirst("language-".count))
            }
        }
        return nil
    }

    private func resolvedURL(from element: Element, attribute: String, baseURL: URL) throws -> URL? {
        let raw = try element.attr(attribute)
        return resolve(raw, baseURL: baseURL)
    }

    private func resolve(_ rawValue: String, baseURL: URL) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let url = URL(string: trimmed, relativeTo: baseURL)?.absoluteURL
        guard let scheme = url?.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return nil
        }
        return url
    }

    private func collectImages(from elements: [DocumentElement]) -> [ImageRef] {
        var values: [ImageRef] = []

        func visit(_ element: DocumentElement) {
            switch element {
            case .image(let image):
                values.append(image)
            case .figure(let image, _):
                values.append(image)
            case .blockquote(let children):
                children.forEach(visit)
            case .list(_, let items):
                items.flatMap { $0 }.forEach(visit)
            default:
                break
            }
        }

        elements.forEach(visit)
        var seen: Set<URL> = []
        return values.filter { image in
            if seen.contains(image.sourceURL) {
                return false
            }
            seen.insert(image.sourceURL)
            return true
        }
    }

    private func firstHeading(in elements: [DocumentElement]) -> String? {
        for element in elements {
            if case .heading(_, let text) = element {
                return text
            }
        }
        return nil
    }

    private func shouldKeepInline(_ inline: [InlineElement]) -> Bool {
        let text = plainText(from: inline)
        return shouldKeepTextBlock(text)
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

    private func shouldKeepImage(
        _ element: Element,
        sourceURL: URL,
        alt: String?,
        width: Int?,
        height: Int?
    ) throws -> Bool {
        var hintParts = [
            sourceURL.absoluteString,
            alt ?? "",
            element.id(),
            try element.classNames().joined(separator: " ")
        ]

        var ancestor = element.parent()
        for _ in 0..<2 {
            guard let current = ancestor else {
                break
            }

            hintParts.append(current.id())
            hintParts.append(try current.classNames().joined(separator: " "))
            ancestor = current.parent()
        }

        let hints = hintParts
            .joined(separator: " ")
            .lowercased()

        if let width, let height, width <= 64, height <= 64 {
            return false
        }

        let altText = alt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasAlt = !altText.isEmpty
        let hasDecorativeMediaHints = [
            "animation",
            "background",
            "bg-",
            "browser-frame",
            "device",
            "frame",
            "gradient",
            "ipad",
            "iphone",
            "laptop",
            "mockup",
            "placeholder",
            "poster",
            "screen-frame",
            "screenshot-frame",
            "texture",
            "video"
        ].contains { hints.contains($0) }

        if isDecorativeCloudAsset(hints: hints, altText: altText) {
            return false
        }

        if hasDecorativeMediaHints && (!hasAlt || isDecorativeAltText(altText)) {
            return false
        }

        if ["arrow", "cloud 1", "cloud 2", "cloud 3"].contains(altText.lowercased()) {
            return false
        }

        let hasUIHints = [
            "avatar",
            "author",
            "profile",
            "headshot",
            "icon",
            "logo",
            "badge",
            "sprite",
            "tracking",
            "pixel",
            "newsletter"
        ].contains { hints.contains($0) }

        if hasUIHints, let width, let height, width <= 220, height <= 220 {
            return false
        }

        if hasUIHints, let alt, alt.count <= 80 {
            return false
        }

        return true
    }

    private func isDecorativeCloudAsset(hints: String, altText: String) -> Bool {
        let compactHints = hints.replacingOccurrences(
            of: "[^a-z0-9]+",
            with: "",
            options: .regularExpression
        )
        let compactAlt = altText
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "", options: .regularExpression)

        if ["cloud1", "cloud2", "cloud3"].contains(compactAlt) {
            return true
        }

        if [
            "cloud1",
            "cloud2",
            "cloud3",
            "cloudone",
            "cloudtwo",
            "cloudthree"
        ].contains(where: { compactHints.contains($0) }) {
            return true
        }

        return altText.isEmpty
            && hints.contains("cloud")
            && (hints.contains("hero") || hints.contains("footer"))
    }

    private func isDecorativeAltText(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        guard !lowercased.isEmpty else {
            return true
        }

        if ["arrow", "cloud 1", "cloud 2", "cloud 3"].contains(lowercased) {
            return true
        }

        guard lowercased.count <= 100 else {
            return false
        }

        return [
            "abstract",
            "background",
            "decorative",
            "gradient",
            "placeholder",
            "texture"
        ].contains { lowercased.contains($0) }
    }

    private func normalized(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedInline(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private func plainTextPreservingTagBoundaries(fromHTML html: String) throws -> String {
        html
            .replacingOccurrences(of: "(?i)<br\\s*/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }

    private func normalizedPreservingLines(_ string: String) -> String {
        string
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct ReadableMetrics {
    var textLength: Int
    var paragraphCount: Int
    var imageCount: Int
    var headingCount: Int
    var listItemCount: Int
    var sentenceCount: Int
    var linkDensity: Double
    var hints: String
}

private struct ContentCandidate {
    var element: Element
    var metrics: ReadableMetrics
    var score: Double

    init(element: Element, metrics: ReadableMetrics) {
        self.element = element
        self.metrics = metrics

        var score = Double(metrics.textLength)
        score += Double(metrics.paragraphCount * 150)
        score += Double(metrics.sentenceCount * 55)
        score += Double(metrics.headingCount * 35)
        score += Double(metrics.imageCount * 25)
        score -= Double(max(0, metrics.listItemCount - metrics.paragraphCount * 2) * 25)

        if Self.hasGoodHint(metrics.hints) {
            score *= 1.35
        }

        if Self.hasBadHint(metrics.hints) {
            score *= 0.28
        }

        if metrics.linkDensity > 0.65 {
            score *= 0.18
        } else if metrics.linkDensity > 0.45 {
            score *= 0.45
        } else if metrics.linkDensity > 0.32 {
            score *= 0.7
        }

        if element.tagName().lowercased() == "body" {
            score *= 0.86
        }

        self.score = score
    }

    static func hasGoodHint(_ hints: String) -> Bool {
        [
            "article",
            "articlebody",
            "body",
            "content",
            "entry",
            "longform",
            "main",
            "post",
            "story",
            "text"
        ].contains { hints.contains($0) }
    }

    private static func hasBadHint(_ hints: String) -> Bool {
        [
            "ad-",
            "ads",
            "advert",
            "banner",
            "breadcrumb",
            "comment",
            "cookie",
            "footer",
            "header",
            "login",
            "menu",
            "newsletter",
            "nav",
            "promo",
            "related",
            "share",
            "sidebar",
            "signup",
            "social",
            "sponsored"
        ].contains { hints.contains($0) }
    }
}

private struct Metadata {
    var title: String?
    var siteName: String?
    var author: String?
    var publishedAt: Date?
    var excerpt: String?
    var heroImage: ImageRef?

    init(document: Document, finalURL: URL) throws {
        let jsonLD = try Self.jsonLDMetadata(document, finalURL: finalURL)

        title = try Self.metaContent(document, property: "og:title")
            ?? Self.metaContent(document, name: "twitter:title")
            ?? jsonLD.title
            ?? document.title().nilIfEmpty

        siteName = try Self.metaContent(document, property: "og:site_name")
            ?? jsonLD.siteName
            ?? finalURL.host(percentEncoded: false)

        author = try Self.metaContent(document, name: "author")
            ?? Self.metaContent(document, property: "article:author")
            ?? jsonLD.author

        excerpt = try Self.metaContent(document, property: "og:description")
            ?? Self.metaContent(document, name: "description")
            ?? jsonLD.excerpt

        if let dateString = try Self.metaContent(document, property: "article:published_time")
            ?? Self.metaContent(document, name: "date")
            ?? jsonLD.publishedAt
            ?? document.select("time[datetime]").first()?.attr("datetime") {
            publishedAt = Self.parseDate(dateString)
        }

        if let imageURLString = try Self.metaContent(document, property: "og:image")
            ?? Self.metaContent(document, name: "twitter:image")
            ?? jsonLD.imageURL,
           let imageURL = URL(string: imageURLString, relativeTo: finalURL)?.absoluteURL {
            heroImage = ImageRef(sourceURL: imageURL)
        }
    }

    static func metaContent(_ document: Document, name: String? = nil, property: String? = nil) throws -> String? {
        let selector: String
        if let name {
            selector = "meta[name=\(name)]"
        } else if let property {
            selector = "meta[property=\(property)]"
        } else {
            return nil
        }

        return try document.select(selector).first()?.attr("content").nilIfEmpty
    }

    static func jsonLDMetadata(_ document: Document, finalURL: URL) throws -> JSONLDMetadata {
        var output = JSONLDMetadata()

        for script in try document.select("script").array() {
            let type = try script.attr("type").lowercased()
            guard type.contains("ld+json") else {
                continue
            }

            let raw = script.data().trimmingCharacters(in: .whitespacesAndNewlines)
            guard let data = raw.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) else {
                continue
            }

            let nodes = jsonLDNodes(from: object)
            let preferredNode = nodes.first(where: isArticleLikeJSONLDNode)
                ?? nodes.first(where: { stringValue(from: $0["headline"]) != nil || stringValue(from: $0["name"]) != nil })

            guard let node = preferredNode else {
                continue
            }

            output.merge(JSONLDMetadata(
                title: stringValue(from: node["headline"]) ?? stringValue(from: node["name"]),
                siteName: namedValue(from: node["publisher"]) ?? namedValue(from: node["isPartOf"]),
                author: authorValue(from: node["author"]),
                publishedAt: stringValue(from: node["datePublished"]) ?? stringValue(from: node["dateCreated"]),
                excerpt: stringValue(from: node["description"]),
                imageURL: imageURLValue(from: node["image"], finalURL: finalURL)
            ))
        }

        return output
    }

    static func jsonLDNodes(from value: Any) -> [[String: Any]] {
        if let array = value as? [Any] {
            return array.flatMap(jsonLDNodes)
        }

        guard let dictionary = value as? [String: Any] else {
            return []
        }

        var nodes = [dictionary]

        for key in ["@graph", "mainEntity", "mainEntityOfPage"] {
            if let nested = dictionary[key] {
                nodes.append(contentsOf: jsonLDNodes(from: nested))
            }
        }

        return nodes
    }

    static func isArticleLikeJSONLDNode(_ node: [String: Any]) -> Bool {
        let rawType = node["@type"]
        let values: [String]

        if let string = rawType as? String {
            values = [string]
        } else if let array = rawType as? [Any] {
            values = array.compactMap { $0 as? String }
        } else {
            values = []
        }

        return values
            .map { $0.lowercased() }
            .contains { type in
                type.contains("article")
                    || type.contains("blogposting")
                    || type.contains("newsarticle")
                    || type.contains("reportage")
                    || type.contains("webpage")
            }
    }

    static func stringValue(from value: Any?) -> String? {
        guard let value else {
            return nil
        }

        if let string = value as? String {
            return string.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        }

        if let number = value as? NSNumber {
            return number.stringValue
        }

        return nil
    }

    static func namedValue(from value: Any?) -> String? {
        if let string = stringValue(from: value) {
            return string
        }

        if let dictionary = value as? [String: Any] {
            return stringValue(from: dictionary["name"])
        }

        return nil
    }

    static func authorValue(from value: Any?) -> String? {
        if let named = namedValue(from: value) {
            return named
        }

        if let array = value as? [Any] {
            let names = array.compactMap(namedValue)
            return names.isEmpty ? nil : names.joined(separator: ", ")
        }

        return nil
    }

    static func imageURLValue(from value: Any?, finalURL: URL) -> String? {
        if let string = stringValue(from: value),
           URL(string: string, relativeTo: finalURL) != nil {
            return string
        }

        if let dictionary = value as? [String: Any] {
            return stringValue(from: dictionary["url"])
                ?? stringValue(from: dictionary["contentUrl"])
        }

        if let array = value as? [Any] {
            return array.compactMap { imageURLValue(from: $0, finalURL: finalURL) }.first
        }

        return nil
    }

    static func parseDate(_ value: String) -> Date? {
        if let date = ISO8601DateFormatter().date(from: value) {
            return date
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}

private struct JSONLDMetadata {
    var title: String?
    var siteName: String?
    var author: String?
    var publishedAt: String?
    var excerpt: String?
    var imageURL: String?

    mutating func merge(_ other: JSONLDMetadata) {
        title = title ?? other.title
        siteName = siteName ?? other.siteName
        author = author ?? other.author
        publishedAt = publishedAt ?? other.publishedAt
        excerpt = excerpt ?? other.excerpt
        imageURL = imageURL ?? other.imageURL
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    var matchesHeadingTag: Bool {
        headingLevel > 0
    }

    var headingLevel: Int {
        guard count == 2, first == "h", let level = last?.wholeNumberValue, (1...6).contains(level) else {
            return 0
        }
        return level
    }
}

private extension Array where Element == InlineElement {
    func trimmed() -> [InlineElement] {
        var values = self

        guard values.count > 1 else {
            if let only = values.first {
                let trimmed = only.trimmingText(in: .whitespacesAndNewlines)
                return trimmed.isEmptyText ? [] : [trimmed]
            }
            return values
        }

        if let first = values.first {
            let trimmed = first.trimmingLeadingText(in: .whitespacesAndNewlines)
            if trimmed.isEmptyText {
                values.removeFirst()
            } else {
                values[0] = trimmed
            }
        }

        if let last = values.last {
            let trimmed = last.trimmingTrailingText(in: .whitespacesAndNewlines)
            if trimmed.isEmptyText {
                values.removeLast()
            } else {
                values[values.count - 1] = trimmed
            }
        }

        return values
    }

    func mergedTextRuns() -> [InlineElement] {
        var result: [InlineElement] = []

        for element in self {
            if case .text(let next) = element,
               case .text(let previous)? = result.last {
                result[result.count - 1] = .text(previous + next)
            } else {
                result.append(element)
            }
        }

        return result
    }

    func repairingSpacing(matching renderedText: String) -> [InlineElement] {
        var result: [InlineElement] = []
        var builtText = ""

        for element in self {
            let text = element.visibleText
            var nextElement = element

            if let previousElement = result.last,
               let previous = result.last?.visibleText,
               !previous.isEmpty,
               !text.isEmpty {
                let withoutSpace = builtText + text
                let withSpace = builtText + " " + text

                if !renderedText.hasPrefix(withoutSpace),
                   renderedText.hasPrefix(withSpace) {
                    nextElement = element.prependingSpace()
                    builtText += " "
                } else if !renderedText.hasPrefix(withoutSpace),
                          previousElement.canLoseTrailingBoundarySpace,
                          element.canLoseLeadingBoundarySpace,
                          !previous.hasSuffix(" "),
                          !text.hasPrefix(" ") {
                    nextElement = element.prependingSpace()
                    builtText += " "
                }
            }

            builtText += text
            result.append(nextElement)
        }

        return result
    }

    func collapsingDuplicateBoundaryWhitespace() -> [InlineElement] {
        var result: [InlineElement] = []

        for element in self {
            var nextElement = element

            if let previousLast = result.last?.visibleText.last,
               let nextFirst = element.visibleText.first,
               previousLast.isWhitespace,
               nextFirst.isWhitespace {
                nextElement = element.trimmingLeadingText(in: .whitespacesAndNewlines)
            }

            if !nextElement.isEmptyText {
                result.append(nextElement)
            }
        }

        return result
    }

    func removingSpacesBeforePunctuation() -> [InlineElement] {
        var result: [InlineElement] = []

        for element in self {
            var nextElement = element

            if let firstMeaningfulCharacter = element.visibleText.firstNonWhitespace,
               firstMeaningfulCharacter.isClosingPunctuation,
               let previous = result.last,
               !previous.visibleText.isEmpty,
               previous.visibleText.last != "\n" {
                let trimmedPrevious = previous.trimmingTrailingText(in: .whitespacesAndNewlines)
                if trimmedPrevious.isEmptyText {
                    result.removeLast()
                } else {
                    result[result.count - 1] = trimmedPrevious
                }

                nextElement = element.trimmingLeadingText(in: .whitespacesAndNewlines)
            }

            if !nextElement.isEmptyText {
                result.append(nextElement)
            }
        }

        return result
    }
}

private extension InlineElement {
    var visibleText: String {
        switch self {
        case .text(let text), .strong(let text), .emphasis(let text), .code(let text):
            return text
        case .link(let text, _):
            return text
        case .lineBreak:
            return "\n"
        }
    }

    var canLoseTrailingBoundarySpace: Bool {
        switch self {
        case .strong, .emphasis, .code, .link:
            return true
        case .text, .lineBreak:
            return false
        }
    }

    var canLoseLeadingBoundarySpace: Bool {
        switch self {
        case .text:
            return true
        case .strong, .emphasis, .code, .link, .lineBreak:
            return false
        }
    }

    var isEmptyText: Bool {
        switch self {
        case .text(let text), .strong(let text), .emphasis(let text), .code(let text):
            return text.isEmpty
        case .link(let text, _):
            return text.isEmpty
        case .lineBreak:
            return false
        }
    }

    func trimmingText(in characterSet: CharacterSet) -> InlineElement {
        switch self {
        case .text(let text):
            return .text(text.trimmingCharacters(in: characterSet))
        case .strong(let text):
            return .strong(text.trimmingCharacters(in: characterSet))
        case .emphasis(let text):
            return .emphasis(text.trimmingCharacters(in: characterSet))
        case .code(let text):
            return .code(text.trimmingCharacters(in: characterSet))
        case .link(let text, let url):
            return .link(text: text.trimmingCharacters(in: characterSet), url: url)
        case .lineBreak:
            return .lineBreak
        }
    }

    func trimmingLeadingText(in characterSet: CharacterSet) -> InlineElement {
        switch self {
        case .text(let text):
            return .text(text.trimmingLeadingCharacters(in: characterSet))
        case .strong(let text):
            return .strong(text.trimmingLeadingCharacters(in: characterSet))
        case .emphasis(let text):
            return .emphasis(text.trimmingLeadingCharacters(in: characterSet))
        case .code(let text):
            return .code(text.trimmingLeadingCharacters(in: characterSet))
        case .link(let text, let url):
            return .link(text: text.trimmingLeadingCharacters(in: characterSet), url: url)
        case .lineBreak:
            return .lineBreak
        }
    }

    func trimmingTrailingText(in characterSet: CharacterSet) -> InlineElement {
        switch self {
        case .text(let text):
            return .text(text.trimmingTrailingCharacters(in: characterSet))
        case .strong(let text):
            return .strong(text.trimmingTrailingCharacters(in: characterSet))
        case .emphasis(let text):
            return .emphasis(text.trimmingTrailingCharacters(in: characterSet))
        case .code(let text):
            return .code(text.trimmingTrailingCharacters(in: characterSet))
        case .link(let text, let url):
            return .link(text: text.trimmingTrailingCharacters(in: characterSet), url: url)
        case .lineBreak:
            return .lineBreak
        }
    }

    func prependingSpace() -> InlineElement {
        switch self {
        case .text(let text):
            return .text(" " + text)
        case .strong(let text):
            return .strong(" " + text)
        case .emphasis(let text):
            return .emphasis(" " + text)
        case .code(let text):
            return .code(" " + text)
        case .link(let text, let url):
            return .link(text: " " + text, url: url)
        case .lineBreak:
            return .lineBreak
        }
    }
}

private extension String {
    var firstNonWhitespace: Character? {
        first { !$0.isWhitespace }
    }

    func trimmingLeadingCharacters(in characterSet: CharacterSet) -> String {
        String(drop(while: { character in
            character.unicodeScalars.allSatisfy { characterSet.contains($0) }
        }))
    }

    func trimmingTrailingCharacters(in characterSet: CharacterSet) -> String {
        String(reversed().drop(while: { character in
            character.unicodeScalars.allSatisfy { characterSet.contains($0) }
        }).reversed())
    }
}

private extension Character {
    var isClosingPunctuation: Bool {
        [".", ",", ";", ":", "!", "?", ")", "]", "}", "%"].contains(self)
    }
}

private extension Array where Element == String {
    func removingDuplicateStrings() -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for value in self where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }

        return result
    }
}

private extension Array where Element == SwiftSoup.Element {
    func removingDuplicateElements() -> [SwiftSoup.Element] {
        var seen = Set<ObjectIdentifier>()
        var result: [SwiftSoup.Element] = []

        for element in self {
            let identifier = ObjectIdentifier(element)
            guard !seen.contains(identifier) else {
                continue
            }
            seen.insert(identifier)
            result.append(element)
        }

        return result
    }
}

private extension Array where Element == DocumentElement {
    func removingAdjacentDuplicateHeadings() -> [DocumentElement] {
        var result: [DocumentElement] = []

        for element in self {
            if case .heading(_, let next) = element,
               case .heading(_, let previous)? = result.last,
               previous == next {
                continue
            }
            result.append(element)
        }

        return result
    }
}
