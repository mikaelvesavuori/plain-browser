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
}

struct QuoteItem: Codable, Equatable, Identifiable {
    var id: UUID
    var text: String
    var sourceURL: URL
    var sourceTitle: String?
    var siteName: String?
    var savedAt: Date

    init(
        id: UUID = UUID(),
        text: String,
        sourceURL: URL,
        sourceTitle: String? = nil,
        siteName: String? = nil,
        savedAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.sourceURL = sourceURL
        self.sourceTitle = sourceTitle
        self.siteName = siteName
        self.savedAt = savedAt
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
