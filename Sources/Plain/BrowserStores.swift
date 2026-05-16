import Foundation

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

struct HistoryStore {
    private let key = "Plain.History"
    private let legacyKey = "Plainview.History"
    private let limit = 20

    func load() -> [HistoryItem] {
        guard let data = UserDefaults.standard.data(forKey: key)
            ?? UserDefaults.standard.data(forKey: legacyKey) else {
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
