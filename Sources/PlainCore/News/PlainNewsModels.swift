import Foundation

public enum PlainNewsSourceKind: String, CaseIterable, Codable, Equatable, Sendable {
    case rss
    case web

    public var label: String {
        switch self {
        case .rss:
            return "RSS"
        case .web:
            return "Web"
        }
    }
}

public enum PlainNewsCategory: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case world
    case technology
    case ai
    case developer
    case infrastructure
    case data
    case business
    case finance
    case policy
    case science
    case health
    case climate
    case energy
    case security
    case culture
    case entertainment
    case gaming
    case ideas

    public var label: String {
        switch self {
        case .world:
            return "World"
        case .technology:
            return "Technology"
        case .ai:
            return "AI"
        case .developer:
            return "Developer"
        case .infrastructure:
            return "Infrastructure"
        case .data:
            return "Data"
        case .business:
            return "Business"
        case .finance:
            return "Finance"
        case .policy:
            return "Policy"
        case .science:
            return "Science"
        case .health:
            return "Health"
        case .climate:
            return "Climate"
        case .energy:
            return "Energy"
        case .security:
            return "Security"
        case .culture:
            return "Culture"
        case .entertainment:
            return "Entertainment"
        case .gaming:
            return "Gaming"
        case .ideas:
            return "Ideas"
        }
    }

    public var systemImage: String {
        switch self {
        case .world:
            return "globe.europe.africa"
        case .technology:
            return "cpu"
        case .ai:
            return "sparkles"
        case .developer:
            return "hammer"
        case .infrastructure:
            return "server.rack"
        case .data:
            return "cylinder.split.1x2"
        case .business:
            return "chart.line.uptrend.xyaxis"
        case .finance:
            return "dollarsign.circle"
        case .policy:
            return "building.columns"
        case .science:
            return "atom"
        case .health:
            return "cross.case"
        case .climate:
            return "leaf"
        case .energy:
            return "bolt"
        case .security:
            return "lock.shield"
        case .culture:
            return "paintpalette"
        case .entertainment:
            return "film"
        case .gaming:
            return "gamecontroller"
        case .ideas:
            return "lightbulb"
        }
    }
}

public struct PlainNewsSource: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var url: URL
    public var kind: PlainNewsSourceKind
    public var categories: [PlainNewsCategory]
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        url: URL,
        kind: PlainNewsSourceKind,
        categories: [PlainNewsCategory] = [],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.kind = kind
        self.categories = Self.normalizedCategories(categories, kind: kind)
        self.isEnabled = isEnabled
    }

    public func belongs(to category: PlainNewsCategory?) -> Bool {
        guard let category else {
            return true
        }
        return categories.contains(category)
    }

    public static func sortedByDisplayName(_ sources: [PlainNewsSource]) -> [PlainNewsSource] {
        sources.sorted { left, right in
            let comparison = left.name.localizedStandardCompare(right.name)
            if comparison == .orderedSame {
                return left.url.absoluteString.localizedStandardCompare(right.url.absoluteString) == .orderedAscending
            }
            return comparison == .orderedAscending
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case url
        case kind
        case categories
        case isEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(PlainNewsSourceKind.self, forKey: .kind)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.url = try container.decode(URL.self, forKey: .url)
        self.kind = kind
        self.categories = Self.normalizedCategories(
            try container.decodeIfPresent([PlainNewsCategory].self, forKey: .categories) ?? [],
            kind: kind
        )
        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(url, forKey: .url)
        try container.encode(kind, forKey: .kind)
        try container.encode(categories, forKey: .categories)
        try container.encode(isEnabled, forKey: .isEnabled)
    }

    private static func normalizedCategories(
        _ categories: [PlainNewsCategory],
        kind: PlainNewsSourceKind
    ) -> [PlainNewsCategory] {
        var seen = Set<PlainNewsCategory>()
        let unique = categories.filter { category in
            guard !seen.contains(category) else {
                return false
            }
            seen.insert(category)
            return true
        }

        if unique.isEmpty {
            return kind == .web ? [.technology] : [.world]
        }

        return unique
    }
}

public struct PlainNewsWindow: Codable, Equatable, Hashable, Sendable {
    public enum Mode: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
        case rollingDays
        case thisWeek
        case yesterday

        public var label: String {
            switch self {
            case .rollingDays:
                return "Rolling"
            case .thisWeek:
                return "This Week"
            case .yesterday:
                return "Yesterday"
            }
        }
    }

    public var mode: Mode
    public var rollingDays: Int

    public init(mode: Mode = .rollingDays, rollingDays: Int = 1) {
        self.mode = mode
        self.rollingDays = Self.clampedRollingDays(rollingDays)
    }

    public static let day = PlainNewsWindow(mode: .rollingDays, rollingDays: 1)
    public static let threeDays = PlainNewsWindow(mode: .rollingDays, rollingDays: 3)
    public static let week = PlainNewsWindow(mode: .rollingDays, rollingDays: 7)
    public static let thisWeek = PlainNewsWindow(mode: .thisWeek, rollingDays: 7)
    public static let yesterday = PlainNewsWindow(mode: .yesterday, rollingDays: 1)

    public static func rolling(days: Int) -> PlainNewsWindow {
        PlainNewsWindow(mode: .rollingDays, rollingDays: days)
    }

    public var label: String {
        switch mode {
        case .rollingDays:
            return rollingDays == 1 ? "Last day" : "Last \(rollingDays) days"
        case .thisWeek:
            return "This week"
        case .yesterday:
            return "Yesterday"
        }
    }

    public var storageValue: String {
        switch mode {
        case .rollingDays:
            return "rolling:\(rollingDays)"
        case .thisWeek:
            return "thisWeek:\(rollingDays)"
        case .yesterday:
            return "yesterday:\(rollingDays)"
        }
    }

    public init?(storageValue: String) {
        switch storageValue {
        case "day":
            self = .day
        case "threeDays":
            self = .threeDays
        case "week":
            self = .week
        case "thisWeek":
            self = .thisWeek
        case "yesterday":
            self = .yesterday
        default:
            let parts = storageValue.split(separator: ":", maxSplits: 1).map(String.init)
            guard let rawMode = parts.first,
                  let mode = Mode(rawValue: rawMode) else {
                return nil
            }
            let days = parts.dropFirst().first.flatMap(Int.init) ?? 7
            self = PlainNewsWindow(mode: mode, rollingDays: days)
        }
    }

    public func withMode(_ mode: Mode) -> PlainNewsWindow {
        PlainNewsWindow(mode: mode, rollingDays: rollingDays)
    }

    public func withRollingDays(_ days: Int) -> PlainNewsWindow {
        PlainNewsWindow(mode: .rollingDays, rollingDays: days)
    }

    func dateInterval(relativeTo now: Date, calendar: Calendar = Self.calendar) -> DateInterval {
        switch mode {
        case .rollingDays:
            return DateInterval(
                start: now.addingTimeInterval(-duration(relativeTo: now, calendar: calendar)),
                end: now.addingTimeInterval(60)
            )
        case .thisWeek:
            let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start
                ?? calendar.startOfDay(for: now)
            return DateInterval(start: start, end: now.addingTimeInterval(60))
        case .yesterday:
            let startOfToday = calendar.startOfDay(for: now)
            let start = calendar.date(byAdding: .day, value: -1, to: startOfToday)
                ?? startOfToday.addingTimeInterval(-24 * 60 * 60)
            return DateInterval(start: start, end: startOfToday)
        }
    }

    func duration(relativeTo now: Date, calendar: Calendar = Self.calendar) -> TimeInterval {
        switch mode {
        case .rollingDays:
            return TimeInterval(rollingDays) * 24 * 60 * 60
        case .thisWeek, .yesterday:
            let interval = dateInterval(relativeTo: now, calendar: calendar)
            return max(1, interval.duration)
        }
    }

    func startDate(relativeTo now: Date, calendar: Calendar = Self.calendar) -> Date {
        dateInterval(relativeTo: now, calendar: calendar).start
    }

    func contains(_ date: Date?, relativeTo now: Date, calendar: Calendar = Self.calendar) -> Bool {
        guard let date else {
            return true
        }
        let interval = dateInterval(relativeTo: now, calendar: calendar)
        return date >= interval.start && date < interval.end
    }

    private enum CodingKeys: String, CodingKey {
        case mode
        case rollingDays
    }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let legacyValue = try? container.decode(String.self),
           let window = PlainNewsWindow(storageValue: legacyValue) {
            self = window
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.mode = try container.decode(Mode.self, forKey: .mode)
        self.rollingDays = Self.clampedRollingDays(
            try container.decodeIfPresent(Int.self, forKey: .rollingDays) ?? 7
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mode, forKey: .mode)
        try container.encode(rollingDays, forKey: .rollingDays)
    }

    private static func clampedRollingDays(_ days: Int) -> Int {
        min(30, max(1, days))
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }
}

public struct PlainNewsArticle: Codable, Equatable, Identifiable, Sendable {
    public var id: String { normalizedURL }
    public var sourceID: UUID
    public var sourceName: String
    public var sourceKind: PlainNewsSourceKind
    public var title: String
    public var url: URL
    public var normalizedURL: String
    public var publishedAt: Date?
    public var observedAt: Date
    public var excerpt: String
    public var content: String

    public init(
        sourceID: UUID,
        sourceName: String,
        sourceKind: PlainNewsSourceKind,
        title: String,
        url: URL,
        publishedAt: Date? = nil,
        observedAt: Date,
        excerpt: String = "",
        content: String = ""
    ) {
        self.sourceID = sourceID
        self.sourceName = sourceName
        self.sourceKind = sourceKind
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.url = url
        self.normalizedURL = Self.normalizedURLString(url)
        self.publishedAt = publishedAt
        self.observedAt = observedAt
        self.excerpt = excerpt.trimmingCharacters(in: .whitespacesAndNewlines)
        self.content = content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func normalizedURLString(_ url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.fragment = nil
        return (components?.url ?? url).absoluteString
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()
    }
}

public struct PlainNewsAssessment: Codable, Equatable, Sendable {
    public var include: Bool
    public var relevance: Int
    public var topics: [String]
    public var reason: String
    public var summary: String
    public var model: String

    public init(
        include: Bool,
        relevance: Int,
        topics: [String],
        reason: String,
        summary: String,
        model: String
    ) {
        self.include = include
        self.relevance = max(0, min(5, relevance))
        self.topics = topics
        self.reason = reason
        self.summary = summary
        self.model = model
    }
}

public struct PlainNewsDigestItem: Codable, Equatable, Identifiable, Sendable {
    public var id: String { article.id }
    public var article: PlainNewsArticle
    public var assessment: PlainNewsAssessment

    public init(article: PlainNewsArticle, assessment: PlainNewsAssessment) {
        self.article = article
        self.assessment = assessment
    }
}

public struct PlainNewsDigest: Codable, Equatable, Sendable {
    public var generatedAt: Date
    public var window: PlainNewsWindow
    public var interestProfile: String
    public var sourceCount: Int
    public var articleCount: Int
    public var modelName: String
    public var items: [PlainNewsDigestItem]

    public init(
        generatedAt: Date,
        window: PlainNewsWindow,
        interestProfile: String,
        sourceCount: Int,
        articleCount: Int,
        modelName: String,
        items: [PlainNewsDigestItem]
    ) {
        self.generatedAt = generatedAt
        self.window = window
        self.interestProfile = interestProfile
        self.sourceCount = sourceCount
        self.articleCount = articleCount
        self.modelName = modelName
        self.items = items
    }
}
