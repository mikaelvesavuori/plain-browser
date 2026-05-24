import AppKit
import Combine
import Foundation
import PlainCore
import UniformTypeIdentifiers

@MainActor
final class BrowserViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading(URL?)
        case loaded(DocumentModel)
        case failed(ReaderFailure)
        case news
    }

    @Published var address: String = ""
    @Published private(set) var state: State = .idle
    @Published private(set) var recentPages: [HistoryItem] = []
    @Published private(set) var laterItems: [LaterItem] = []
    @Published private(set) var newsSources: [PlainNewsSource] = []
    @Published var newsInterestProfile: String = "" {
        didSet {
            newsStore.saveInterests(newsInterestProfile)
        }
    }
    @Published var newsWindow: PlainNewsWindow = .day {
        didSet {
            newsStore.saveWindow(newsWindow)
        }
    }
    @Published private(set) var newsDigest: PlainNewsDigest?
    @Published private(set) var newsProgress: PlainNewsProgress?
    @Published private(set) var newsErrorMessage: String?
    @Published private(set) var newsAIStatus: PlainNewsAIStatus = PlainNewsIntelligenceFactory.availabilityStatus()
    @Published private(set) var isNewsRunning = false
    @Published var showsImages: Bool = true
    @Published private(set) var statusMessage: String?
    @Published private(set) var updateNotice: AppUpdate?

    private var pipeline = DocumentPipeline()
    private var documents: [DocumentModel] = []
    private var currentIndex: Int?
    private let historyStore = HistoryStore()
    private let laterStore = LaterStore()
    private let newsStore = PlainNewsStore()
    private var newsPipeline = PlainNewsPipeline()
    private let imageCache = ImageCache()
    private let handoffParser = URLHandoffParser()
    private let exporter = DocumentTextExporter()
    private let updateChecker = ReleaseUpdateChecker()
    private var newsReturnNavigation = PlainNewsReturnNavigation()
    private var laterReadingSequence = PlainLaterReadingSequence()
    private var didHandleStartupArguments = false
    private var didCheckForUpdates = false

    init() {
        recentPages = historyStore.load()
        laterItems = laterStore.load()
        newsSources = newsStore.loadSources()
        newsInterestProfile = newsStore.loadInterests()
        newsWindow = newsStore.loadWindow()
        try? imageCache.prune()
    }

    var canGoBack: Bool {
        if canReturnToNewsFromCurrentSurface {
            return true
        }

        switch state {
        case .loaded, .failed:
            break
        case .idle, .loading, .news:
            return false
        }

        guard let currentIndex else { return false }
        return currentIndex > 0
    }

    var canGoForward: Bool {
        switch state {
        case .loaded, .failed:
            break
        case .idle, .loading, .news:
            return false
        }

        guard let currentIndex else { return false }
        return currentIndex < documents.count - 1
    }

    var canGoToPreviousLaterItem: Bool {
        guard canNavigateLaterItems else {
            return false
        }
        return laterReadingSequence.canMovePrevious(in: laterURLs)
    }

    var canGoToNextLaterItem: Bool {
        guard canNavigateLaterItems else {
            return false
        }
        return laterReadingSequence.canMoveNext(in: laterURLs)
    }

    var currentDocument: DocumentModel? {
        if case .loaded(let document) = state {
            return document
        }
        return nil
    }

    var currentURL: URL? {
        switch state {
        case .loading(let url):
            return url
        case .loaded(let document):
            return document.finalURL
        case .failed(let failure):
            return failure.url
        case .news:
            return nil
        case .idle:
            return nil
        }
    }

    var currentIsInLater: Bool {
        if activeLaterIndex != nil {
            return true
        }

        guard let currentURL else {
            return false
        }

        return isURLInLater(currentURL)
    }

    func loadAddress() {
        let input = address
        clearNewsReturn()
        clearLaterNavigation()
        Task {
            await load(input)
        }
    }

    func reloadCurrent() {
        guard let currentURL else {
            loadAddress()
            return
        }

        address = currentURL.absoluteString
        Task {
            await load(currentURL.absoluteString)
        }
    }

    func loadRecent(_ item: HistoryItem) {
        address = item.url.absoluteString
        clearNewsReturn()
        clearLaterNavigation()
        loadAddress()
    }

    func loadLater(_ item: LaterItem) {
        loadLaterItem(item)
    }

    func showHistory() {
        address = ""
        clearNewsReturn()
        clearLaterNavigation()
        state = .idle
    }

    func showNews() {
        address = ""
        state = .news
    }

    func openLink(_ url: URL) {
        address = url.absoluteString
        clearLaterNavigation()
        Task {
            await load(url.absoluteString)
        }
    }

    func openHandoffURL(_ url: URL) {
        guard let sourceURL = handoffParser.sourceURL(from: url) else {
            return
        }
        clearNewsReturn()
        openLink(sourceURL)
    }

    func loadStartupURLIfAvailable() {
        guard !didHandleStartupArguments else {
            return
        }
        didHandleStartupArguments = true

        for argument in ProcessInfo.processInfo.arguments.dropFirst() {
            if let url = handoffParser.sourceURL(from: argument) {
                address = url.absoluteString
                clearLaterNavigation()
                Task {
                    await load(url.absoluteString)
                }
                return
            }
        }
    }

    func checkForUpdatesOnStartup() {
        guard !didCheckForUpdates,
              let currentVersion = appShortVersion else {
            return
        }

        didCheckForUpdates = true
        Task {
            updateNotice = await updateChecker.check(currentVersion: currentVersion)
        }
    }

    func openLatestRelease() {
        guard let releaseURL = updateNotice?.releaseURL else {
            return
        }

        NSWorkspace.shared.open(releaseURL)
        updateNotice = nil
    }

    func dismissUpdateNotice() {
        updateNotice = nil
    }

    func goBack() {
        if canReturnToNewsFromCurrentSurface {
            address = ""
            newsReturnNavigation.clearFailureReturn()
            state = .news
            return
        }

        guard let currentIndex, currentIndex > 0 else {
            return
        }
        let nextIndex = currentIndex - 1
        clearLaterNavigation()
        self.currentIndex = nextIndex
        let document = documents[nextIndex]
        address = document.finalURL.absoluteString
        state = .loaded(document)
    }

    func goForward() {
        guard let currentIndex, currentIndex < documents.count - 1 else {
            return
        }
        let nextIndex = currentIndex + 1
        clearLaterNavigation()
        self.currentIndex = nextIndex
        let document = documents[nextIndex]
        address = document.finalURL.absoluteString
        state = .loaded(document)
    }

    func openCurrentInDefaultBrowser() {
        guard let currentURL else {
            return
        }
        NSWorkspace.shared.open(currentURL)
    }

    func reportCurrentPageIssue() {
        guard let reportURL = makeReportIssueURL() else {
            setStatus("Could not open report")
            return
        }

        NSWorkspace.shared.open(reportURL)
        setStatus("Report draft opened")
    }

    func clearHistory() {
        recentPages = []
        historyStore.save([])
        setStatus("History cleared")
    }

    func toggleCurrentLater() {
        guard let currentURL else {
            return
        }

        let currentURLString = PlainNewsArticle.normalizedURLString(currentURL)
        if let existingItem = laterItems.first(where: { item in
            let itemURLString = PlainNewsArticle.normalizedURLString(item.url)
            return itemURLString == currentURLString || laterReadingSequence.containsActiveURL(item.url)
        }) {
            laterItems = laterStore.remove(existingItem, from: laterItems)
            if laterReadingSequence.containsActiveURL(existingItem.url) {
                clearLaterNavigation()
            }
            setStatus("Removed from Later")
            return
        }

        let item = LaterItem(
            url: currentURL,
            title: currentDocument?.title,
            addedAt: Date()
        )
        laterItems = laterStore.add(item, to: laterItems)
        setStatus("Saved for Later")
    }

    func removeFromLater(_ item: LaterItem) {
        laterItems = laterStore.remove(item, from: laterItems)
        if laterReadingSequence.containsActiveURL(item.url) {
            clearLaterNavigation()
        }
        setStatus("Removed from Later")
    }

    func clearLater() {
        laterItems = []
        clearLaterNavigation()
        laterStore.save([])
        setStatus("Later cleared")
    }

    func loadPreviousLaterItem() {
        guard canGoToPreviousLaterItem,
              let index = activeLaterIndex else {
            return
        }
        loadLaterItem(laterItems[index - 1])
    }

    func loadNextLaterItem() {
        guard canGoToNextLaterItem,
              let index = activeLaterIndex else {
            return
        }
        loadLaterItem(laterItems[index + 1])
    }

    func isNewsItemInLater(_ item: PlainNewsDigestItem) -> Bool {
        isURLInLater(item.article.url)
    }

    func saveNewsItemForLater(_ item: PlainNewsDigestItem) {
        guard !isNewsItemInLater(item) else {
            setStatus("Already saved for Later")
            return
        }

        let laterItem = LaterItem(
            url: item.article.url,
            title: item.article.title,
            addedAt: Date()
        )
        laterItems = laterStore.add(laterItem, to: laterItems)
        setStatus("Saved for Later")
    }

    func addNewsSource(
        name: String,
        urlString: String,
        kind: PlainNewsSourceKind,
        categories: [PlainNewsCategory]
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = trimmedName.isEmpty ? "Untitled source" : trimmedName

        guard let url = normalizedNewsURL(from: urlString) else {
            newsErrorMessage = "Use a valid RSS or web URL."
            return
        }

        let normalizedURL = PlainNewsArticle.normalizedURLString(url)
        guard !newsSources.contains(where: { PlainNewsArticle.normalizedURLString($0.url) == normalizedURL }) else {
            newsErrorMessage = "That source is already in Plain News."
            return
        }

        newsSources.append(PlainNewsSource(name: fallbackName, url: url, kind: kind, categories: categories))
        newsStore.saveSources(newsSources)
        newsErrorMessage = nil
        setStatus("News source added")
    }

    func addNewsPreset(_ source: PlainNewsSource) {
        let normalizedURL = PlainNewsArticle.normalizedURLString(source.url)
        guard !newsSources.contains(where: { PlainNewsArticle.normalizedURLString($0.url) == normalizedURL }) else {
            newsErrorMessage = "That source is already in Plain News."
            return
        }

        newsSources.append(source)
        newsStore.saveSources(newsSources)
        newsErrorMessage = nil
        setStatus("News source added")
    }

    func toggleNewsSource(_ source: PlainNewsSource) {
        guard let index = newsSources.firstIndex(where: { $0.id == source.id }) else {
            return
        }

        newsSources[index].isEnabled.toggle()
        newsStore.saveSources(newsSources)
    }

    func removeNewsSource(_ source: PlainNewsSource) {
        newsSources.removeAll { $0.id == source.id }
        newsStore.saveSources(newsSources)
        setStatus("News source removed")
    }

    func clearNewsDigest() {
        newsDigest = nil
        newsProgress = nil
        newsErrorMessage = nil
    }

    func runPlainNews() {
        guard !isNewsRunning else {
            return
        }

        let enabledSources = newsSources.filter(\.isEnabled)
        guard !enabledSources.isEmpty else {
            newsErrorMessage = "Add or enable at least one source."
            return
        }

        let pipeline = newsPipeline
        let window = newsWindow
        let interests = newsInterestProfile
        isNewsRunning = true
        newsDigest = nil
        newsErrorMessage = nil
        newsProgress = PlainNewsProgress(stage: .collecting, message: "Collecting sources", completed: 0, total: enabledSources.count)
        state = .news

        Task {
            let digest = await pipeline.run(
                sources: enabledSources,
                window: window,
                interestProfile: interests
            ) { progress in
                await MainActor.run {
                    self.newsProgress = progress
                }
            }

            self.newsDigest = digest
            self.isNewsRunning = false
            self.newsProgress = nil
            self.setStatus("Plain News ready")
        }
    }

    func openNewsItem(_ item: PlainNewsDigestItem) {
        newsReturnNavigation.prepareForOpen()
        openLink(item.article.url)
    }

    func exportLater() {
        guard !laterItems.isEmpty else {
            setStatus("Later is empty")
            return
        }

        let panel = NSSavePanel()
        panel.title = "Export Later"
        panel.nameFieldStringValue = "Plain Later.md"
        if let markdownType = UTType(filenameExtension: "md") {
            panel.allowedContentTypes = [markdownType, .plainText]
        } else {
            panel.allowedContentTypes = [.plainText]
        }
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try laterMarkdown().write(to: url, atomically: true, encoding: .utf8)
            setStatus("Later exported")
        } catch {
            setStatus("Could not export Later")
        }
    }

    func clearCache() {
        do {
            try imageCache.clear()
            setStatus("Image cache cleared")
        } catch {
            setStatus("Could not clear image cache")
        }
    }

    func copyCleanText() {
        guard let currentDocument else {
            return
        }
        copyToPasteboard(exporter.plainText(from: currentDocument))
        setStatus("Clean text copied")
    }

    func copyMarkdown() {
        guard let currentDocument else {
            return
        }
        copyToPasteboard(exporter.markdown(from: currentDocument))
        setStatus("Markdown copied")
    }

    private func load(_ input: String) async {
        statusMessage = nil
        let loadingURL = URL(string: input)
        state = .loading(loadingURL)

        do {
            let document = try await pipeline.load(input, fetchImages: showsImages)
            applyLoadedDocument(document)
        } catch {
            newsReturnNavigation.failLoad()
            state = .failed(
                ReaderFailure(
                    url: loadingURL,
                    title: "Could not load this page",
                    message: error.localizedDescription
                )
            )
        }
    }

    private func applyLoadedDocument(_ document: DocumentModel) {
        if let currentIndex {
            documents = Array(documents.prefix(currentIndex + 1))
        }

        documents.append(document)
        currentIndex = documents.count - 1
        if let currentIndex {
            newsReturnNavigation.completeLoad(documentIndex: currentIndex)
        }
        address = document.finalURL.absoluteString
        state = .loaded(document)

        let item = HistoryItem(
            url: document.finalURL,
            title: document.title,
            visitedAt: Date()
        )
        recentPages = historyStore.add(item, to: recentPages)
    }

    private func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private var canReturnToNewsFromCurrentSurface: Bool {
        switch state {
        case .loaded:
            return newsReturnNavigation.canReturnFromLoadedDocument(currentIndex: currentIndex)
        case .failed:
            return newsReturnNavigation.canReturnFromFailure
        case .idle, .loading, .news:
            return false
        }
    }

    private func clearNewsReturn() {
        newsReturnNavigation.clear()
    }

    private var laterURLs: [URL] {
        laterItems.map(\.url)
    }

    private var activeLaterIndex: Int? {
        laterReadingSequence.activeIndex(in: laterURLs)
    }

    private var canNavigateLaterItems: Bool {
        switch state {
        case .loaded, .failed:
            return true
        case .idle, .loading, .news:
            return false
        }
    }

    private func loadLaterItem(_ item: LaterItem) {
        clearNewsReturn()
        laterReadingSequence.activate(url: item.url)
        address = item.url.absoluteString
        Task {
            await load(item.url.absoluteString)
        }
    }

    private func clearLaterNavigation() {
        laterReadingSequence.clear()
    }

    private func isURLInLater(_ url: URL) -> Bool {
        let normalized = PlainNewsArticle.normalizedURLString(url)
        return laterItems.contains { item in
            PlainNewsArticle.normalizedURLString(item.url) == normalized
        }
    }

    private func makeReportIssueURL() -> URL? {
        guard let currentURL else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "hello@browseplain.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Plain page issue: \(currentURL.host(percentEncoded: false) ?? currentURL.absoluteString)"),
            URLQueryItem(name: "body", value: reportIssueBody(for: currentURL))
        ]
        return components.url
    }

    private func reportIssueBody(for url: URL) -> String {
        var pageDetails = [
            "URL: \(url.absoluteString)",
            "address input: \(address)"
        ]

        switch state {
        case .loaded(let document):
            pageDetails.append("title: \(document.title ?? "Untitled")")
            pageDetails.append("extraction quality: \(document.extractionQuality.rawValue)")
        case .failed(let failure):
            pageDetails.append("failure: \(failure.title)")
            pageDetails.append("message: \(failure.message)")
        case .loading, .idle, .news:
            break
        }

        let sections = [
            "Plain had trouble with this page.",
            "Page: \(pageDetails.joined(separator: "; ")).",
            "Plain context: images enabled: \(showsImages ? "yes" : "no"); app version: \(appVersionString); macOS: \(ProcessInfo.processInfo.operatingSystemVersionString).",
            "What looked wrong: none yet.",
            "What did you expect: none yet.",
            "Screenshot attached: none."
        ]

        return sections.joined(separator: " ")
    }

    private var appVersionString: String {
        let version = appShortVersion
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (version, build) {
        case let (version?, build?):
            return "\(version) (\(build))"
        case let (version?, nil):
            return version
        default:
            return "development"
        }
    }

    private var appShortVersion: String? {
        guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            return nil
        }

        let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func laterMarkdown() -> String {
        let rows = laterItems.map { item in
            let trimmedTitle = item.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackTitle = item.url.absoluteString
            let label = (trimmedTitle?.isEmpty == false ? trimmedTitle! : fallbackTitle)
                .replacingOccurrences(of: "[", with: "\\[")
                .replacingOccurrences(of: "]", with: "\\]")

            return "- [\(label)](\(item.url.absoluteString))"
        }

        return """
        # Plain Later

        \(rows.joined(separator: "\n"))

        """
    }

    private func setStatus(_ message: String) {
        statusMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            if statusMessage == message {
                statusMessage = nil
            }
        }
    }

    private func normalizedNewsURL(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return url
        }

        return URL(string: "https://\(trimmed)")
    }
}
