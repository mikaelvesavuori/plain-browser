import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

public protocol PlainNewsIntelligence: Sendable {
    var modelName: String { get }
    func assess(article: PlainNewsArticle, interestProfile: String) async -> PlainNewsAssessment
}

public struct PlainNewsAIStatus: Equatable, Sendable {
    public var title: String
    public var detail: String
    public var isAppleFoundationModelsAvailable: Bool

    public init(title: String, detail: String, isAppleFoundationModelsAvailable: Bool) {
        self.title = title
        self.detail = detail
        self.isAppleFoundationModelsAvailable = isAppleFoundationModelsAvailable
    }
}

public enum PlainNewsIntelligenceFactory {
    public static func preferred() -> any PlainNewsIntelligence {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let intelligence = AppleFoundationNewsIntelligence()
            if intelligence.isAvailable {
                return intelligence
            }
        }
        #endif

        return HeuristicPlainNewsIntelligence()
    }

    public static func availabilityStatus() -> PlainNewsAIStatus {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let intelligence = AppleFoundationNewsIntelligence()
            if intelligence.isAvailable {
                return PlainNewsAIStatus(
                    title: "Apple Foundation Models",
                    detail: "Local Apple AI is available for article selection and summaries.",
                    isAppleFoundationModelsAvailable: true
                )
            }

            return PlainNewsAIStatus(
                title: "Local heuristic",
                detail: "Apple Foundation Models are present but not available to Plain right now.",
                isAppleFoundationModelsAvailable: false
            )
        }

        return PlainNewsAIStatus(
            title: "Local heuristic",
            detail: "Apple Foundation Models require macOS 26 or later.",
            isAppleFoundationModelsAvailable: false
        )
        #else
        return PlainNewsAIStatus(
            title: "Local heuristic",
            detail: "This build cannot import Apple's Foundation Models framework.",
            isAppleFoundationModelsAvailable: false
        )
        #endif
    }
}

public struct HeuristicPlainNewsIntelligence: PlainNewsIntelligence {
    public let modelName = "Local heuristic"

    public init() {}

    public func assess(article: PlainNewsArticle, interestProfile: String) async -> PlainNewsAssessment {
        let terms = Self.interestTerms(from: interestProfile)
        let text = [article.title, article.excerpt, article.content]
            .joined(separator: " ")
            .lowercased()
        let title = article.title.lowercased()
        let matchedTerms = terms.filter { term in
            text.contains(term)
        }
        var relevance = terms.isEmpty ? 3 : 1

        for term in matchedTerms {
            relevance += title.contains(term) ? 2 : 1
        }

        if article.sourceKind == .rss, article.excerpt.count > 80 {
            relevance += 1
        }

        relevance = max(0, min(5, relevance))
        let include = terms.isEmpty ? relevance >= 3 : relevance >= 3
        let summary = Self.summary(for: article)
        let topics = Array(matchedTerms.prefix(5))
        let reason: String

        if terms.isEmpty {
            reason = "No interests set; selected for recency, source balance, and available excerpt."
        } else if matchedTerms.isEmpty {
            reason = "No clear match for the current interests."
        } else {
            reason = "Matches \(matchedTerms.prefix(3).joined(separator: ", "))."
        }

        return PlainNewsAssessment(
            include: include,
            relevance: relevance,
            topics: topics,
            reason: reason,
            summary: summary,
            model: modelName
        )
    }

    static func cheapScore(article: PlainNewsArticle, interestProfile: String, now: Date = Date()) -> Int {
        let terms = interestTerms(from: interestProfile)
        let title = article.title.lowercased()
        let text = [article.title, article.excerpt, article.content]
            .joined(separator: " ")
            .lowercased()
        var score = terms.isEmpty ? 20 : 0

        for term in terms where text.contains(term) {
            score += title.contains(term) ? 18 : 10
        }

        if let publishedAt = article.publishedAt {
            let hours = max(0, now.timeIntervalSince(publishedAt) / 3600)
            score += max(0, 18 - Int(hours / 6))
        } else {
            score += 4
        }

        if article.excerpt.count > 80 {
            score += 8
        }

        return score
    }

    static func interestTerms(from value: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",\n")
        let rawTerms = value
            .components(separatedBy: separators)
            .flatMap { chunk in
                chunk.components(separatedBy: CharacterSet(charactersIn: ";"))
            }
        var seen = Set<String>()

        return rawTerms
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
            }
            .filter { term in
                guard term.count >= 3, !seen.contains(term) else {
                    return false
                }
                seen.insert(term)
                return true
            }
    }

    static func summary(for article: PlainNewsArticle, limit: Int = 220) -> String {
        let candidate = article.excerpt.isEmpty ? article.content : article.excerpt
        let normalized = candidate
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else {
            return article.title
        }

        if normalized.count <= limit {
            return normalized
        }

        let prefix = String(normalized.prefix(limit))
        if let sentenceEnd = prefix.lastIndex(where: { ".!?".contains($0) }) {
            return String(prefix[...sentenceEnd])
        }

        return "\(prefix.trimmingCharacters(in: .whitespacesAndNewlines))..."
    }
}

#if canImport(FoundationModels)
@available(macOS 26.0, *)
public struct AppleFoundationNewsIntelligence: PlainNewsIntelligence {
    public let modelName = "Apple Foundation Models"
    private let fallback = HeuristicPlainNewsIntelligence()

    public init() {}

    public var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    public func assess(article: PlainNewsArticle, interestProfile: String) async -> PlainNewsAssessment {
        guard isAvailable else {
            return await fallback.assess(article: article, interestProfile: interestProfile)
        }

        do {
            let session = LanguageModelSession(instructions: """
            You classify articles for a private local reading digest. Be calm, terse, and source-grounded. Return only valid JSON with include, relevance, topics, reason, and summary.
            """)
            let response = try await session.respond(
                to: prompt(article: article, interestProfile: interestProfile),
                options: GenerationOptions(temperature: 0.1, maximumResponseTokens: 260)
            )
            return try decodeAssessment(response.content)
        } catch {
            return await fallback.assess(article: article, interestProfile: interestProfile)
        }
    }

    private func prompt(article: PlainNewsArticle, interestProfile: String) -> String {
        let payload = ArticlePayload(
            interestProfile: interestProfile,
            title: article.title,
            source: article.sourceName,
            published: article.publishedAt?.ISO8601Format() ?? "",
            excerpt: article.excerpt,
            content: String(article.content.prefix(2400))
        )
        let data = (try? JSONEncoder().encode(payload)) ?? Data()
        let json = String(data: data, encoding: .utf8) ?? "{}"

        return """
        User interests:
        \(interestProfile.isEmpty ? "General calm daily reading." : interestProfile)

        Article payload:
        \(json)

        Return only valid JSON:
        {
          "include": true,
          "relevance": 0,
          "topics": ["topic"],
          "reason": "short reason",
          "summary": "one sentence, no invented facts"
        }
        """
    }

    private func decodeAssessment(_ value: String) throws -> PlainNewsAssessment {
        let json = extractJSONObject(from: value)
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(DecodedAssessment.self, from: data)
        return PlainNewsAssessment(
            include: decoded.include,
            relevance: decoded.relevance,
            topics: decoded.topics,
            reason: decoded.reason,
            summary: decoded.summary,
            model: modelName
        )
    }

    private func extractJSONObject(from value: String) -> String {
        guard let start = value.firstIndex(of: "{"),
              let end = value.lastIndex(of: "}"),
              start <= end else {
            return value
        }

        return String(value[start...end])
    }

    private struct ArticlePayload: Encodable {
        var interestProfile: String
        var title: String
        var source: String
        var published: String
        var excerpt: String
        var content: String
    }

    private struct DecodedAssessment: Decodable {
        var include: Bool
        var relevance: Int
        var topics: [String]
        var reason: String
        var summary: String
    }
}
#endif
