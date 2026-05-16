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
    }

    @Published var address: String = ""
    @Published private(set) var state: State = .idle
    @Published private(set) var recentPages: [HistoryItem] = []
    @Published private(set) var laterItems: [LaterItem] = []
    @Published var showsImages: Bool = true
    @Published private(set) var statusMessage: String?
    @Published private(set) var updateNotice: AppUpdate?

    private var pipeline = DocumentPipeline()
    private var documents: [DocumentModel] = []
    private var currentIndex: Int?
    private let historyStore = HistoryStore()
    private let laterStore = LaterStore()
    private let imageCache = ImageCache()
    private let handoffParser = URLHandoffParser()
    private let exporter = DocumentTextExporter()
    private let updateChecker = ReleaseUpdateChecker()
    private var didHandleStartupArguments = false
    private var didCheckForUpdates = false

    init() {
        recentPages = historyStore.load()
        laterItems = laterStore.load()
        try? imageCache.prune()
    }

    var canGoBack: Bool {
        guard let currentIndex else { return false }
        return currentIndex > 0
    }

    var canGoForward: Bool {
        guard let currentIndex else { return false }
        return currentIndex < documents.count - 1
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
        case .idle:
            return nil
        }
    }

    var currentIsInLater: Bool {
        guard let currentURL else {
            return false
        }
        return laterItems.contains { $0.url == currentURL }
    }

    func loadAddress() {
        let input = address
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
        loadAddress()
    }

    func loadLater(_ item: LaterItem) {
        address = item.url.absoluteString
        loadAddress()
    }

    func showHistory() {
        address = ""
        state = .idle
    }

    func openLink(_ url: URL) {
        address = url.absoluteString
        Task {
            await load(url.absoluteString)
        }
    }

    func openHandoffURL(_ url: URL) {
        guard let sourceURL = handoffParser.sourceURL(from: url) else {
            return
        }
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
        guard let currentIndex, currentIndex > 0 else {
            return
        }
        let nextIndex = currentIndex - 1
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

        if let existingItem = laterItems.first(where: { $0.url == currentURL }) {
            laterItems = laterStore.remove(existingItem, from: laterItems)
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
        setStatus("Removed from Later")
    }

    func clearLater() {
        laterItems = []
        laterStore.save([])
        setStatus("Later cleared")
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
        case .loading, .idle:
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
}
