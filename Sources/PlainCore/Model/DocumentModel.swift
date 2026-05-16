import Foundation

public struct DocumentModel: Codable, Equatable, Sendable {
    public var id: UUID
    public var sourceURL: URL
    public var finalURL: URL
    public var title: String?
    public var siteName: String?
    public var author: String?
    public var publishedAt: Date?
    public var excerpt: String?
    public var heroImage: ImageRef?
    public var elements: [DocumentElement]
    public var images: [ImageRef]
    public var fetchedAt: Date
    public var extractionQuality: ExtractionQuality

    public init(
        id: UUID = UUID(),
        sourceURL: URL,
        finalURL: URL,
        title: String? = nil,
        siteName: String? = nil,
        author: String? = nil,
        publishedAt: Date? = nil,
        excerpt: String? = nil,
        heroImage: ImageRef? = nil,
        elements: [DocumentElement],
        images: [ImageRef],
        fetchedAt: Date,
        extractionQuality: ExtractionQuality
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.finalURL = finalURL
        self.title = title
        self.siteName = siteName
        self.author = author
        self.publishedAt = publishedAt
        self.excerpt = excerpt
        self.heroImage = heroImage
        self.elements = elements
        self.images = images
        self.fetchedAt = fetchedAt
        self.extractionQuality = extractionQuality
    }
}

public enum ExtractionQuality: String, Codable, Equatable, Sendable {
    case strong
    case fallback
    case weak
}

public enum DocumentElement: Codable, Equatable, Sendable {
    case heading(level: Int, text: String)
    case paragraph([InlineElement])
    case searchResult(SearchResult)
    case image(ImageRef)
    case figure(image: ImageRef, caption: String?)
    case blockquote([DocumentElement])
    case list(ordered: Bool, items: [[DocumentElement]])
    case codeBlock(language: String?, code: String)
    case table(SimpleTable)
    case horizontalRule
    case linkPreview(url: URL, text: String?)
}

public struct SearchResult: Codable, Equatable, Sendable {
    public var title: String
    public var url: URL
    public var displayURL: String?
    public var snippet: String?

    public init(
        title: String,
        url: URL,
        displayURL: String? = nil,
        snippet: String? = nil
    ) {
        self.title = title
        self.url = url
        self.displayURL = displayURL
        self.snippet = snippet
    }
}

public enum InlineElement: Codable, Equatable, Sendable {
    case text(String)
    case strong(String)
    case emphasis(String)
    case code(String)
    case link(text: String, url: URL)
    case lineBreak
}

public struct SimpleTable: Codable, Equatable, Sendable {
    public var headers: [String]
    public var rows: [[String]]

    public init(headers: [String], rows: [[String]]) {
        self.headers = headers
        self.rows = rows
    }
}

public struct ImageRef: Codable, Equatable, Sendable {
    public var id: UUID
    public var sourceURL: URL
    public var localPath: URL?
    public var alt: String?
    public var caption: String?
    public var width: Int?
    public var height: Int?
    public var mimeType: String?

    public init(
        id: UUID = UUID(),
        sourceURL: URL,
        localPath: URL? = nil,
        alt: String? = nil,
        caption: String? = nil,
        width: Int? = nil,
        height: Int? = nil,
        mimeType: String? = nil
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.localPath = localPath
        self.alt = alt
        self.caption = caption
        self.width = width
        self.height = height
        self.mimeType = mimeType
    }
}
