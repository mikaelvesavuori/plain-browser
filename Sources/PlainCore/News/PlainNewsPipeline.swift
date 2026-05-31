import Foundation

public struct PlainNewsPipeline: Sendable {
    public var dataFetcher: PlainNewsDataFetcher
    public var feedParser: PlainNewsFeedParser
    public var documentPipeline: DocumentPipeline
    public var textExporter: DocumentTextExporter
    public var intelligence: any PlainNewsIntelligence
    public var maxFeedItemsPerSource: Int
    public var maxWebCandidatesPerSource: Int
    public var maxAssessedArticles: Int
    public var maxDigestItems: Int

    public init(
        dataFetcher: PlainNewsDataFetcher = PlainNewsDataFetcher(),
        feedParser: PlainNewsFeedParser = PlainNewsFeedParser(),
        documentPipeline: DocumentPipeline = DocumentPipeline(),
        textExporter: DocumentTextExporter = DocumentTextExporter(),
        intelligence: any PlainNewsIntelligence = PlainNewsIntelligenceFactory.preferred(),
        maxFeedItemsPerSource: Int = 120,
        maxWebCandidatesPerSource: Int = 10,
        maxAssessedArticles: Int = 36,
        maxDigestItems: Int = 12
    ) {
        self.dataFetcher = dataFetcher
        self.feedParser = feedParser
        self.documentPipeline = documentPipeline
        self.textExporter = textExporter
        self.intelligence = intelligence
        self.maxFeedItemsPerSource = maxFeedItemsPerSource
        self.maxWebCandidatesPerSource = maxWebCandidatesPerSource
        self.maxAssessedArticles = maxAssessedArticles
        self.maxDigestItems = maxDigestItems
    }

    public func run(
        sources: [PlainNewsSource],
        window: PlainNewsWindow,
        interestProfile: String,
        now: Date = Date(),
        progress: (@Sendable (PlainNewsProgress) async -> Void)? = nil
    ) async -> PlainNewsDigest {
        let activeSources = sources.filter(\.isEnabled)
        await progress?(PlainNewsProgress(stage: .collecting, message: "Collecting sources", completed: 0, total: activeSources.count))
        var articles: [PlainNewsArticle] = []
        var completedSources = 0

        for source in activeSources {
            let sourceArticles: [PlainNewsArticle]
            switch source.kind {
            case .rss:
                sourceArticles = (try? await collectRSSArticles(from: source, window: window, now: now)) ?? []
            case .web:
                sourceArticles = await collectWebArticles(from: source, window: window, now: now)
            }

            articles.append(contentsOf: sourceArticles)
            completedSources += 1
            await progress?(PlainNewsProgress(
                stage: .collecting,
                message: "\(source.name)",
                completed: completedSources,
                total: activeSources.count
            ))
        }

        let deduped = dedupe(articles)
            .filter { article in
                window.contains(article.publishedAt ?? article.observedAt, relativeTo: now)
            }
        let rankedArticles = deduped
            .sorted { left, right in
                let leftScore = HeuristicPlainNewsIntelligence.cheapScore(article: left, interestProfile: interestProfile, now: now)
                let rightScore = HeuristicPlainNewsIntelligence.cheapScore(article: right, interestProfile: interestProfile, now: now)

                if leftScore != rightScore {
                    return leftScore > rightScore
                }

                return (left.publishedAt ?? left.observedAt) > (right.publishedAt ?? right.observedAt)
            }
        let timeBalancedArticlePool = PlainNewsTemporalDiversifier.diversified(
            rankedArticles,
            maxCount: min(rankedArticles.count, maxAssessedArticles * 2),
            window: window,
            now: now
        ) { article in
            article.publishedAt ?? article.observedAt
        }
        let shortlisted = PlainNewsSourceDiversifier.diversified(
            timeBalancedArticlePool,
            maxCount: maxAssessedArticles
        ) { article in
            article.sourceID
        }

        await progress?(PlainNewsProgress(stage: .assessing, message: "Reading locally", completed: 0, total: shortlisted.count))
        var assessedItems: [PlainNewsDigestItem] = []
        var usedModels = Set<String>()
        var completedAssessments = 0

        for article in shortlisted {
            let assessment = await intelligence.assess(article: article, interestProfile: interestProfile)
            usedModels.insert(assessment.model)
            completedAssessments += 1
            await progress?(PlainNewsProgress(
                stage: .assessing,
                message: article.sourceName,
                completed: completedAssessments,
                total: shortlisted.count
            ))

            guard assessment.include else {
                continue
            }

            assessedItems.append(PlainNewsDigestItem(article: article, assessment: assessment))
        }

        let rankedItems = assessedItems
            .sorted { left, right in
                if left.assessment.relevance != right.assessment.relevance {
                    return left.assessment.relevance > right.assessment.relevance
                }

                return (left.article.publishedAt ?? left.article.observedAt) > (right.article.publishedAt ?? right.article.observedAt)
            }
        let timeBalancedItemPool = PlainNewsTemporalDiversifier.diversified(
            rankedItems,
            maxCount: min(rankedItems.count, maxDigestItems * 2),
            window: window,
            now: now
        ) { item in
            item.article.publishedAt ?? item.article.observedAt
        }
        let items = PlainNewsSourceDiversifier.diversified(
            timeBalancedItemPool,
            maxCount: maxDigestItems
        ) { item in
            item.article.sourceID
        }
        .sorted { left, right in
            (left.article.publishedAt ?? left.article.observedAt) > (right.article.publishedAt ?? right.article.observedAt)
        }

        await progress?(PlainNewsProgress(stage: .complete, message: "Plain News ready", completed: items.count, total: items.count))

        return PlainNewsDigest(
            generatedAt: now,
            window: window,
            interestProfile: interestProfile,
            sourceCount: activeSources.count,
            articleCount: deduped.count,
            modelName: modelSummary(from: usedModels) ?? intelligence.modelName,
            items: Array(items)
        )
    }

    private func modelSummary(from usedModels: Set<String>) -> String? {
        guard !usedModels.isEmpty else {
            return nil
        }

        if usedModels.count == 1 {
            return usedModels.first
        }

        return usedModels.sorted().joined(separator: " + ")
    }

    private func collectRSSArticles(
        from source: PlainNewsSource,
        window: PlainNewsWindow,
        now: Date
    ) async throws -> [PlainNewsArticle] {
        let result = try await dataFetcher.fetch(source.url, acceptHeader: "application/rss+xml,application/atom+xml,application/xml,text/xml;q=0.9,*/*;q=0.1")
        let articles: [PlainNewsArticle] = try feedParser.parse(result.data, sourceURL: result.finalURL)
            .compactMap { item in
                guard let url = item.url,
                      window.contains(item.publishedAt, relativeTo: now) else {
                    return nil
                }

                return PlainNewsArticle(
                    sourceID: source.id,
                    sourceName: source.name,
                    sourceKind: source.kind,
                    title: item.title,
                    url: url,
                    publishedAt: item.publishedAt,
                    observedAt: now,
                    excerpt: item.summary,
                    content: [item.title, item.summary].filter { !$0.isEmpty }.joined(separator: "\n\n")
                )
            }
        return Array(articles.prefix(maxFeedItemsPerSource))
    }

    private func collectWebArticles(
        from source: PlainNewsSource,
        window: PlainNewsWindow,
        now: Date
    ) async -> [PlainNewsArticle] {
        guard let sourceDocument = try? await documentPipeline.load(source.url.absoluteString, fetchImages: false) else {
            return []
        }

        let links = linkCandidates(from: sourceDocument)
            .prefix(maxWebCandidatesPerSource)
        var articles: [PlainNewsArticle] = []

        for link in links {
            guard let document = try? await documentPipeline.load(link.url.absoluteString, fetchImages: false) else {
                articles.append(PlainNewsArticle(
                    sourceID: source.id,
                    sourceName: source.name,
                    sourceKind: source.kind,
                    title: link.title,
                    url: link.url,
                    publishedAt: nil,
                    observedAt: now,
                    excerpt: link.excerpt,
                    content: link.excerpt
                ))
                continue
            }

            guard window.contains(document.publishedAt ?? document.fetchedAt, relativeTo: now) else {
                continue
            }

            let plainText = textExporter.plainText(from: document)
            articles.append(PlainNewsArticle(
                sourceID: source.id,
                sourceName: source.name,
                sourceKind: source.kind,
                title: document.title ?? link.title,
                url: document.finalURL,
                publishedAt: document.publishedAt,
                observedAt: document.fetchedAt,
                excerpt: document.excerpt ?? link.excerpt,
                content: plainText
            ))
        }

        return articles
    }

    private func linkCandidates(from document: DocumentModel) -> [PlainNewsLinkCandidate] {
        var candidates: [PlainNewsLinkCandidate] = []
        var seen = Set<String>()

        for element in document.elements {
            collectLinkCandidates(from: element, into: &candidates, seen: &seen)
        }

        return candidates
            .filter { candidate in
                candidate.url.host(percentEncoded: false) != nil && candidate.url != document.finalURL
            }
    }

    private func collectLinkCandidates(
        from element: DocumentElement,
        into candidates: inout [PlainNewsLinkCandidate],
        seen: inout Set<String>
    ) {
        switch element {
        case .searchResult(let result):
            appendCandidate(
                url: result.url,
                title: result.title,
                excerpt: result.snippet ?? "",
                into: &candidates,
                seen: &seen
            )
        case .linkPreview(let url, let text):
            appendCandidate(url: url, title: text ?? url.absoluteString, excerpt: "", into: &candidates, seen: &seen)
        case .paragraph(let inline):
            for inlineElement in inline {
                if case .link(let text, let url) = inlineElement {
                    appendCandidate(url: url, title: text, excerpt: "", into: &candidates, seen: &seen)
                }
            }
        case .blockquote(let elements):
            for child in elements {
                collectLinkCandidates(from: child, into: &candidates, seen: &seen)
            }
        case .list(_, let items):
            for item in items {
                for child in item {
                    collectLinkCandidates(from: child, into: &candidates, seen: &seen)
                }
            }
        default:
            break
        }
    }

    private func appendCandidate(
        url: URL,
        title: String,
        excerpt: String,
        into candidates: inout [PlainNewsLinkCandidate],
        seen: inout Set<String>
    ) {
        let normalizedTitle = title
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedURL = PlainNewsArticle.normalizedURLString(url)
        guard (8...180).contains(normalizedTitle.count),
              !seen.contains(normalizedURL),
              shouldKeepCandidate(url: url, title: normalizedTitle) else {
            return
        }

        seen.insert(normalizedURL)
        candidates.append(PlainNewsLinkCandidate(url: url, title: normalizedTitle, excerpt: excerpt))
    }

    private func shouldKeepCandidate(url: URL, title: String) -> Bool {
        let lowercasedTitle = title.lowercased()
        let blockedTitles = [
            "advertisement",
            "comments",
            "cookie",
            "log in",
            "login",
            "privacy",
            "read more",
            "sign in",
            "sign up",
            "subscribe"
        ]

        if blockedTitles.contains(where: { lowercasedTitle == $0 || lowercasedTitle.contains($0) && title.count <= 42 }) {
            return false
        }

        let path = url.path.lowercased()
        if path.hasSuffix(".css") || path.hasSuffix(".js") || path.hasSuffix(".png") || path.hasSuffix(".jpg") || path.hasSuffix(".jpeg") || path.hasSuffix(".svg") || path.hasSuffix(".pdf") {
            return false
        }

        return true
    }

    private func dedupe(_ articles: [PlainNewsArticle]) -> [PlainNewsArticle] {
        var seen = Set<String>()
        return articles.filter { article in
            guard !seen.contains(article.normalizedURL) else {
                return false
            }
            seen.insert(article.normalizedURL)
            return true
        }
    }
}

public struct PlainNewsProgress: Equatable, Sendable {
    public enum Stage: Equatable, Sendable {
        case collecting
        case assessing
        case complete
    }

    public var stage: Stage
    public var message: String
    public var completed: Int
    public var total: Int

    public init(stage: Stage, message: String, completed: Int, total: Int) {
        self.stage = stage
        self.message = message
        self.completed = completed
        self.total = total
    }
}

enum PlainNewsTemporalDiversifier {
    static func diversified<Value>(
        _ rankedValues: [Value],
        maxCount: Int,
        window: PlainNewsWindow,
        now: Date,
        date: (Value) -> Date
    ) -> [Value] {
        guard maxCount > 0 else {
            return []
        }

        let bucketCount = bucketCount(for: window, maxCount: maxCount, now: now)
        guard bucketCount > 1, rankedValues.count > maxCount else {
            return Array(rankedValues.prefix(maxCount))
        }

        let ranked = Array(rankedValues.enumerated())
        var buckets = [[(offset: Int, element: Value)]](repeating: [], count: bucketCount)

        for value in ranked {
            let bucket = ageBucket(for: date(value.element), bucketCount: bucketCount, window: window, now: now)
            buckets[bucket].append(value)
        }

        let quotaPerBucket = max(1, maxCount / bucketCount)
        var selectedOffsets = Set<Int>()
        var selected: [(offset: Int, element: Value)] = []

        for bucket in buckets {
            for value in bucket.prefix(quotaPerBucket) where selected.count < maxCount {
                selected.append(value)
                selectedOffsets.insert(value.offset)
            }
        }

        for value in ranked where selected.count < maxCount && !selectedOffsets.contains(value.offset) {
            selected.append(value)
            selectedOffsets.insert(value.offset)
        }

        return selected.map(\.element)
    }

    private static func bucketCount(for window: PlainNewsWindow, maxCount: Int, now: Date) -> Int {
        switch window.mode {
        case .rollingDays:
            return min(maxCount, max(1, window.rollingDays))
        case .thisWeek:
            let elapsedDays = Int(ceil(window.duration(relativeTo: now) / (24 * 60 * 60)))
            return min(maxCount, max(1, elapsedDays))
        case .yesterday:
            return 1
        }
    }

    private static func ageBucket(
        for date: Date,
        bucketCount: Int,
        window: PlainNewsWindow,
        now: Date
    ) -> Int {
        let age = max(0, now.timeIntervalSince(date))
        let bucketDuration = max(1, window.duration(relativeTo: now) / Double(bucketCount))
        return min(bucketCount - 1, Int(age / bucketDuration))
    }
}

enum PlainNewsSourceDiversifier {
    static func diversified<Value, SourceID: Hashable>(
        _ rankedValues: [Value],
        maxCount: Int,
        sourceID: (Value) -> SourceID
    ) -> [Value] {
        guard maxCount > 0 else {
            return []
        }

        guard rankedValues.count > maxCount else {
            return rankedValues
        }

        let ranked = Array(rankedValues.enumerated())
        var selectedOffsets = Set<Int>()
        var selected: [(offset: Int, element: Value)] = []
        var coveredSources = Set<SourceID>()

        for value in ranked where selected.count < maxCount {
            let source = sourceID(value.element)
            guard !coveredSources.contains(source) else {
                continue
            }

            selected.append(value)
            selectedOffsets.insert(value.offset)
            coveredSources.insert(source)
        }

        for value in ranked where selected.count < maxCount && !selectedOffsets.contains(value.offset) {
            selected.append(value)
            selectedOffsets.insert(value.offset)
        }

        return selected.map(\.element)
    }
}

public struct PlainNewsDataFetcher: Sendable {
    public var maxResponseBytes: Int
    public var maxRedirects: Int
    public var timeout: TimeInterval
    public var userAgent: String
    public var safetyValidator: URLSafetyValidator
    public var addressValidator: ResolvedAddressValidator
    public var privacyConfiguration: FetchPrivacyConfiguration

    public init(
        maxResponseBytes: Int = 2_000_000,
        maxRedirects: Int = 8,
        timeout: TimeInterval = 15,
        userAgent: String = "Plain/0.1",
        safetyValidator: URLSafetyValidator = URLSafetyValidator(),
        addressValidator: ResolvedAddressValidator? = nil
    ) {
        self.maxResponseBytes = maxResponseBytes
        self.maxRedirects = maxRedirects
        self.timeout = timeout
        self.userAgent = userAgent
        self.safetyValidator = safetyValidator
        self.addressValidator = addressValidator ?? ResolvedAddressValidator(safetyValidator: safetyValidator)
        self.privacyConfiguration = FetchPrivacyConfiguration(timeout: timeout)
    }

    public func fetch(_ url: URL, acceptHeader: String) async throws -> (data: Data, finalURL: URL) {
        try await addressValidator.validate(url)

        let session = URLSession(configuration: privacyConfiguration.makeURLSessionConfiguration())
        defer {
            session.finishTasksAndInvalidate()
        }

        var currentURL = url
        var redirectsFollowed = 0

        while true {
            var request = plainRequest(for: currentURL, timeout: timeout, userAgent: userAgent, kind: .html)
            request.setValue(acceptHeader, forHTTPHeaderField: "Accept")

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: request, delegate: NoAutomaticRedirectDelegate())
            } catch {
                throw PlainError.fetchFailed(error.localizedDescription)
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                throw PlainError.fetchFailed("The server did not return an HTTP response.")
            }

            if let redirectURL = try HTTPRedirect.target(from: httpResponse, baseURL: currentURL) {
                guard redirectsFollowed < maxRedirects else {
                    throw PlainError.tooManyRedirects(maxRedirects)
                }
                try await addressValidator.validate(redirectURL)
                redirectsFollowed += 1
                currentURL = redirectURL
                continue
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                throw PlainError.badStatus(httpResponse.statusCode)
            }

            guard data.count <= maxResponseBytes else {
                throw PlainError.responseTooLarge(data.count)
            }

            let finalURL = httpResponse.url ?? currentURL
            try await addressValidator.validate(finalURL)
            return (data, finalURL)
        }
    }
}

private struct PlainNewsLinkCandidate: Sendable {
    var url: URL
    var title: String
    var excerpt: String
}
