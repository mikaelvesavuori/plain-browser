import Foundation
import PlainCore

struct ReaderFailure: Equatable {
    var url: URL?
    var title: String
    var message: String
}

struct HistoryItem: Codable, Equatable, Identifiable {
    var id: String { url.absoluteString }
    var url: URL
    var title: String?
    var visitedAt: Date
}

struct LaterItem: Codable, Equatable, Identifiable {
    var id: String { url.absoluteString }
    var url: URL
    var title: String?
    var addedAt: Date
    var tags: [String]
    var readingProgress: Double
    var lastReadAt: Date?

    init(
        url: URL,
        title: String? = nil,
        addedAt: Date = Date(),
        tags: [String] = [],
        readingProgress: Double = 0,
        lastReadAt: Date? = nil
    ) {
        self.url = url
        self.title = title
        self.addedAt = addedAt
        self.tags = QuoteItem.normalizedTags(tags)
        self.readingProgress = Self.clampedProgress(readingProgress)
        self.lastReadAt = lastReadAt
    }

    private enum CodingKeys: String, CodingKey {
        case url
        case title
        case addedAt
        case tags
        case readingProgress
        case lastReadAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = try container.decode(URL.self, forKey: .url)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        addedAt = try container.decode(Date.self, forKey: .addedAt)
        tags = QuoteItem.normalizedTags(try container.decodeIfPresent([String].self, forKey: .tags) ?? [])
        readingProgress = Self.clampedProgress(try container.decodeIfPresent(Double.self, forKey: .readingProgress) ?? 0)
        lastReadAt = try container.decodeIfPresent(Date.self, forKey: .lastReadAt)
    }

    func withTags(_ tags: [String]) -> LaterItem {
        LaterItem(
            url: url,
            title: title,
            addedAt: addedAt,
            tags: tags,
            readingProgress: readingProgress,
            lastReadAt: lastReadAt
        )
    }

    func withReadingProgress(_ progress: Double, readAt: Date = Date()) -> LaterItem {
        LaterItem(
            url: url,
            title: title,
            addedAt: addedAt,
            tags: tags,
            readingProgress: progress,
            lastReadAt: readAt
        )
    }

    static func clampedProgress(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

struct QuoteItem: Codable, Equatable, Identifiable {
    var id: UUID
    var text: String
    var sourceURL: URL
    var sourceTitle: String?
    var siteName: String?
    var savedAt: Date
    var note: String?
    var tags: [String]

    init(
        id: UUID = UUID(),
        text: String,
        sourceURL: URL,
        sourceTitle: String? = nil,
        siteName: String? = nil,
        savedAt: Date = Date(),
        note: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.text = text
        self.sourceURL = sourceURL
        self.sourceTitle = sourceTitle
        self.siteName = siteName
        self.savedAt = savedAt
        self.note = note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.tags = Self.normalizedTags(tags)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case text
        case sourceURL
        case sourceTitle
        case siteName
        case savedAt
        case note
        case tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        sourceURL = try container.decode(URL.self, forKey: .sourceURL)
        sourceTitle = try container.decodeIfPresent(String.self, forKey: .sourceTitle)
        siteName = try container.decodeIfPresent(String.self, forKey: .siteName)
        savedAt = try container.decode(Date.self, forKey: .savedAt)
        note = try container.decodeIfPresent(String.self, forKey: .note)?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        tags = Self.normalizedTags(try container.decodeIfPresent([String].self, forKey: .tags) ?? [])
    }

    func withMetadata(note: String?, tags: [String]) -> QuoteItem {
        QuoteItem(
            id: id,
            text: text,
            sourceURL: sourceURL,
            sourceTitle: sourceTitle,
            siteName: siteName,
            savedAt: savedAt,
            note: note,
            tags: tags
        )
    }

    static func normalizedTags(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values
            .flatMap { value in
                value.components(separatedBy: CharacterSet(charactersIn: ",#\n"))
            }
            .map { value in
                value.trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
            }
            .filter { value in
                guard !value.isEmpty, !seen.contains(value) else {
                    return false
                }
                seen.insert(value)
                return true
            }
    }
}

struct HistoryStore {
    private let key = "Plain.History"
    private let limit = 20

    func load() -> [HistoryItem] {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return []
        }
        return (try? JSONDecoder().decode([HistoryItem].self, from: data)) ?? []
    }

    func add(_ item: HistoryItem, to existing: [HistoryItem]) -> [HistoryItem] {
        var values = existing.filter { $0.url != item.url }
        values.insert(item, at: 0)
        values = Array(values.prefix(limit))
        save(values)
        return values
    }

    func save(_ items: [HistoryItem]) {
        guard let data = try? JSONEncoder().encode(items) else {
            return
        }
        UserDefaults.standard.set(data, forKey: key)
    }
}

struct LaterStore {
    private let key = "Plain.Later"
    private let limit = 80

    func load() -> [LaterItem] {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return []
        }
        return (try? JSONDecoder().decode([LaterItem].self, from: data)) ?? []
    }

    func add(_ item: LaterItem, to existing: [LaterItem]) -> [LaterItem] {
        var values = existing.filter { $0.url != item.url }
        values.insert(item, at: 0)
        values = Array(values.prefix(limit))
        save(values)
        return values
    }

    func remove(_ item: LaterItem, from existing: [LaterItem]) -> [LaterItem] {
        let values = existing.filter { $0.url != item.url }
        save(values)
        return values
    }

    func save(_ items: [LaterItem]) {
        guard let data = try? JSONEncoder().encode(items) else {
            return
        }
        UserDefaults.standard.set(data, forKey: key)
    }
}

struct QuoteStore {
    private let key = "Plain.Quotes"

    func load() -> [QuoteItem] {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return []
        }
        return (try? JSONDecoder().decode([QuoteItem].self, from: data)) ?? []
    }

    func add(_ item: QuoteItem, to existing: [QuoteItem]) -> [QuoteItem] {
        var values = existing
        values.insert(item, at: 0)
        save(values)
        return values
    }

    func remove(_ item: QuoteItem, from existing: [QuoteItem]) -> [QuoteItem] {
        let values = existing.filter { $0.id != item.id }
        save(values)
        return values
    }

    func save(_ items: [QuoteItem]) {
        guard let data = try? JSONEncoder().encode(items) else {
            return
        }
        UserDefaults.standard.set(data, forKey: key)
    }
}

struct PlainNewsStore {
    private let sourcesKey = "Plain.News.Sources"
    private let interestsKey = "Plain.News.Interests"
    private let windowKey = "Plain.News.Window"
    private let limitsResultsKey = "Plain.News.LimitsResults"
    private let resultLimitKey = "Plain.News.ResultLimit"

    func loadSources() -> [PlainNewsSource] {
        guard let data = UserDefaults.standard.data(forKey: sourcesKey) else {
            return []
        }
        guard let sources = try? JSONDecoder().decode([PlainNewsSource].self, from: data) else {
            return []
        }

        let activeSources = sources.filter { source in
            !PlainNewsPresetSources.retiredSourceURLStrings.contains(PlainNewsArticle.normalizedURLString(source.url))
        }

        if activeSources.count != sources.count {
            saveSources(activeSources)
        }

        return activeSources
    }

    func saveSources(_ sources: [PlainNewsSource]) {
        guard let data = try? JSONEncoder().encode(sources) else {
            return
        }
        UserDefaults.standard.set(data, forKey: sourcesKey)
    }

    func loadInterests() -> String {
        UserDefaults.standard.string(forKey: interestsKey) ?? ""
    }

    func saveInterests(_ value: String) {
        UserDefaults.standard.set(value, forKey: interestsKey)
    }

    func loadWindow() -> PlainNewsWindow {
        guard let rawValue = UserDefaults.standard.string(forKey: windowKey),
              let window = PlainNewsWindow(storageValue: rawValue) else {
            return .day
        }
        return window
    }

    func saveWindow(_ window: PlainNewsWindow) {
        UserDefaults.standard.set(window.storageValue, forKey: windowKey)
    }

    func loadLimitsResults() -> Bool {
        guard UserDefaults.standard.object(forKey: limitsResultsKey) != nil else {
            return true
        }
        return UserDefaults.standard.bool(forKey: limitsResultsKey)
    }

    func saveLimitsResults(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: limitsResultsKey)
    }

    func loadResultLimit() -> Int {
        let value = UserDefaults.standard.integer(forKey: resultLimitKey)
        guard value > 0 else {
            return 12
        }
        return clampedResultLimit(value)
    }

    func saveResultLimit(_ value: Int) {
        UserDefaults.standard.set(clampedResultLimit(value), forKey: resultLimitKey)
    }

    private func clampedResultLimit(_ value: Int) -> Int {
        min(60, max(6, value))
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
