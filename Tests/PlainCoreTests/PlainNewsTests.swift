import Foundation
@testable import PlainCore
import XCTest

final class PlainNewsTests: XCTestCase {
    func testFeedParserReadsRssItems() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
          <channel>
            <item>
              <title>Quiet browsers are having a moment</title>
              <link>/articles/plain-news</link>
              <pubDate>Thu, 21 May 2026 09:30:00 +0000</pubDate>
              <description><![CDATA[<p>A short note about calmer reading tools.</p>]]></description>
            </item>
          </channel>
        </rss>
        """
        let parser = PlainNewsFeedParser()

        let items = try parser.parse(Data(xml.utf8), sourceURL: URL(string: "https://example.com/feed.xml")!)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "Quiet browsers are having a moment")
        XCTAssertEqual(items[0].url?.absoluteString, "https://example.com/articles/plain-news")
        XCTAssertEqual(items[0].summary, "A short note about calmer reading tools.")
        XCTAssertNotNil(items[0].publishedAt)
    }

    func testFeedParserReadsAtomLinks() throws {
        let xml = """
        <feed xmlns="http://www.w3.org/2005/Atom">
          <entry>
            <title>Local summaries</title>
            <link href="https://example.com/local-summaries"/>
            <updated>2026-05-21T10:15:00Z</updated>
            <summary>Apple-native digest work.</summary>
          </entry>
        </feed>
        """
        let parser = PlainNewsFeedParser()

        let items = try parser.parse(Data(xml.utf8), sourceURL: URL(string: "https://example.com/atom.xml")!)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].url?.absoluteString, "https://example.com/local-summaries")
        XCTAssertEqual(items[0].summary, "Apple-native digest work.")
        XCTAssertNotNil(items[0].publishedAt)
    }

    func testHeuristicIntelligenceScoresMatchingInterests() async {
        let intelligence = HeuristicPlainNewsIntelligence()
        let article = PlainNewsArticle(
            sourceID: UUID(),
            sourceName: "Example",
            sourceKind: .rss,
            title: "Local AI makes daily reading calmer",
            url: URL(string: "https://example.com/local-ai")!,
            publishedAt: Date(),
            observedAt: Date(),
            excerpt: "A report on local AI summaries and quieter news digests.",
            content: ""
        )

        let assessment = await intelligence.assess(article: article, interestProfile: "local AI, privacy")

        XCTAssertTrue(assessment.include)
        XCTAssertGreaterThanOrEqual(assessment.relevance, 3)
        XCTAssertTrue(assessment.topics.contains("local ai"))
    }

    func testPresetSourcesIncludeMultiCategoryFeeds() {
        XCTAssertGreaterThanOrEqual(PlainNewsPresetSources.sources.count, 100)
        XCTAssertTrue(PlainNewsPresetSources.sources.allSatisfy { !$0.categories.isEmpty })
        XCTAssertTrue(PlainNewsPresetSources.sources.contains { source in
            source.categories.count > 1
        })
        XCTAssertTrue(PlainNewsPresetSources.sources.contains { source in
            source.kind == .rss && source.categories.contains(.security)
        })
        XCTAssertTrue(PlainNewsPresetSources.sources.contains { source in
            source.kind == .rss && source.categories.contains(.ai)
        })
        XCTAssertTrue(PlainNewsPresetSources.sources.contains { source in
            source.kind == .rss && source.categories.contains(.infrastructure)
        })
        XCTAssertTrue(PlainNewsPresetSources.sources.contains { source in
            source.kind == .rss && source.categories.contains(.policy)
        })
        XCTAssertTrue(PlainNewsPresetSources.sources.contains { source in
            source.kind == .rss && source.categories.contains(.gaming)
        })
        XCTAssertTrue(PlainNewsPresetSources.sources.contains { source in
            source.kind == .rss && source.categories.contains(.entertainment)
        })
    }

    func testPresetSourcesUseStableUniqueIdentifiersAndURLs() {
        let sources = PlainNewsPresetSources.sources
        XCTAssertEqual(Set(sources.map(\.id)).count, sources.count)
        XCTAssertEqual(Set(sources.map { $0.url.absoluteString }).count, sources.count)
    }

    func testPresetSourcesAreAlphabetized() {
        let names = PlainNewsPresetSources.sources.map(\.name)
        let sortedNames = names.sorted { left, right in
            left.localizedStandardCompare(right) == .orderedAscending
        }

        XCTAssertEqual(names, sortedNames)
    }

    func testSourceSortingUsesDisplayNameAndURLTieBreak() {
        let sources = [
            PlainNewsSource(name: "Zeta", url: URL(string: "https://example.com/z")!, kind: .rss),
            PlainNewsSource(name: "Alpha", url: URL(string: "https://example.com/b")!, kind: .rss),
            PlainNewsSource(name: "Alpha", url: URL(string: "https://example.com/a")!, kind: .rss)
        ]

        XCTAssertEqual(
            PlainNewsSource.sortedByDisplayName(sources).map(\.url.absoluteString),
            [
                "https://example.com/a",
                "https://example.com/b",
                "https://example.com/z"
            ]
        )
    }

    func testWeekWindowIncludesFullSevenDays() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-22T12:00:00Z"))
        let sixDaysAgo = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-16T12:00:00Z"))
        let eightDaysAgo = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-14T12:00:00Z"))

        XCTAssertTrue(PlainNewsWindow.week.contains(sixDaysAgo, relativeTo: now))
        XCTAssertFalse(PlainNewsWindow.week.contains(eightDaysAgo, relativeTo: now))
    }

    func testThisWeekWindowStartsOnMonday() throws {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-22T12:00:00Z"))
        let monday = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-18T00:00:00Z"))
        let sunday = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-17T23:59:59Z"))

        XCTAssertTrue(PlainNewsWindow.thisWeek.contains(monday, relativeTo: now, calendar: calendar))
        XCTAssertFalse(PlainNewsWindow.thisWeek.contains(sunday, relativeTo: now, calendar: calendar))
    }

    func testYesterdayWindowIncludesOnlyPreviousCalendarDay() throws {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-22T12:00:00Z"))
        let yesterday = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-21T18:00:00Z"))
        let today = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-22T00:00:00Z"))
        let dayBeforeYesterday = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-20T23:59:59Z"))

        XCTAssertTrue(PlainNewsWindow.yesterday.contains(yesterday, relativeTo: now, calendar: calendar))
        XCTAssertFalse(PlainNewsWindow.yesterday.contains(today, relativeTo: now, calendar: calendar))
        XCTAssertFalse(PlainNewsWindow.yesterday.contains(dayBeforeYesterday, relativeTo: now, calendar: calendar))
    }

    func testWindowStorageSupportsLegacyAndNewValues() {
        let thisWeek = PlainNewsWindow(mode: .thisWeek, rollingDays: 14)

        XCTAssertEqual(PlainNewsWindow(storageValue: "day"), .day)
        XCTAssertEqual(PlainNewsWindow(storageValue: "week"), .week)
        XCTAssertEqual(PlainNewsWindow(storageValue: thisWeek.storageValue), thisWeek)
        XCTAssertEqual(PlainNewsWindow.rolling(days: 60).rollingDays, 30)
    }

    func testWeekDiversifierKeepsOlderBuckets() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-22T12:00:00Z"))
        let rankedDates = try (0..<14).map { index in
            try XCTUnwrap(Calendar(identifier: .gregorian).date(
                byAdding: .hour,
                value: -(index * 12),
                to: now
            ))
        }

        let selected = PlainNewsTemporalDiversifier.diversified(
            rankedDates,
            maxCount: 7,
            window: .week,
            now: now
        ) { $0 }

        XCTAssertEqual(selected.count, 7)
        XCTAssertTrue(selected.contains { now.timeIntervalSince($0) >= 5 * 24 * 60 * 60 })
    }

    func testPresetSourcesAvoidNicheVendorFeeds() {
        let removedNames: Set<String> = [
            "Arize Blog",
            "ClickHouse Blog",
            "Confluent Blog",
            "Databricks Blog",
            "Datadog Blog",
            "dbt Labs Blog",
            "Fastly Blog",
            "GitLab Blog",
            "HashiCorp Blog",
            "Hugging Face Blog",
            "LangChain Blog",
            "MongoDB Blog",
            "OVHcloud Blog",
            "Snowflake Blog"
        ]
        let names = Set(PlainNewsPresetSources.sources.map(\.name))

        XCTAssertTrue(names.isDisjoint(with: removedNames))
        XCTAssertTrue(PlainNewsPresetSources.sources.allSatisfy { source in
            !PlainNewsPresetSources.retiredSourceURLStrings.contains(PlainNewsArticle.normalizedURLString(source.url))
        })
    }

    func testPresetSourcesIncludeGamingAndEntertainmentFeeds() {
        let names = Set(PlainNewsPresetSources.sources.map(\.name))

        XCTAssertTrue(names.isSuperset(of: [
            "Game Informer",
            "IGN Games",
            "Kotaku",
            "Polygon Gaming",
            "Video Games Chronicle"
        ]))
    }

    func testSourceDecodingDefaultsCategoriesForExistingStoredSources() throws {
        let json = """
        {
          "id": "4E33D954-2F13-45E3-8942-FC7F6B9C8E73",
          "name": "Hacker News",
          "url": "https://news.ycombinator.com/",
          "kind": "web",
          "isEnabled": true
        }
        """

        let source = try JSONDecoder().decode(PlainNewsSource.self, from: Data(json.utf8))

        XCTAssertEqual(source.categories, [.technology])
    }
}
