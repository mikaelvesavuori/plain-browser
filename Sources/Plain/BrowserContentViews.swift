import AppKit
import PlainCore
import SwiftUI

struct StartView: View {
    var recentPages: [HistoryItem]
    var laterItems: [LaterItem]
    var quoteItems: [QuoteItem]
    var showsWelcome: Bool
    var topChromeInset: CGFloat
    var onOpen: (HistoryItem) -> Void
    var onOpenLater: (LaterItem) -> Void
    var onRemoveLater: (LaterItem) -> Void
    var onUpdateLaterTags: (LaterItem, [String]) -> Void
    var onExportLater: () -> Void
    var onImportLater: () -> Void
    var onClearLater: () -> Void
    var onShowNews: () -> Void
    var onShowQuotes: () -> Void
    var onClear: () -> Void
    var onDismissWelcome: () -> Void

    @State private var laterSearchText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                brandHeader

                if showsWelcome {
                    FirstRunPlainNote(onDismiss: onDismissWelcome)
                }

                PlainNewsStartRow(onOpen: onShowNews)

                QuoteLibraryStartRow(
                    quoteItems: quoteItems,
                    onOpen: onShowQuotes
                )

                if !laterItems.isEmpty {
                    laterSection
                }

                if recentPages.isEmpty && laterItems.isEmpty && quoteItems.isEmpty {
                    EmptyRecentView()
                } else if !recentPages.isEmpty {
                    recentSection
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: 840, alignment: .leading)
            .padding(.horizontal, 42)
            .padding(.top, 56 + topChromeInset)
            .padding(.bottom, 56)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(StartBackground())
    }

    private var brandHeader: some View {
        HStack(alignment: .center, spacing: 20) {
            PlainMarkView(size: 76, iconSize: 33)

            VStack(alignment: .leading, spacing: 6) {
                Text("Plain")
                    .font(.system(size: 52, weight: .semibold, design: .serif))
                Text("When you want the readable web, browse Plain.")
                    .font(.system(size: 16.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var laterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeading(title: "Later", subtitle: "\(laterItems.count) saved")
                Spacer()
                Button("Import") {
                    onImportLater()
                }
                .buttonStyle(.link)
                Button("Export") {
                    onExportLater()
                }
                .buttonStyle(.link)
                Button("Clear") {
                    onClearLater()
                }
                .buttonStyle(.link)
            }

            LibrarySearchField(placeholder: "Search Later by title, URL, or tag", text: $laterSearchText)

            if filteredLaterItems.isEmpty {
                EmptyFilteredLibraryView(
                    title: "No matching Later items",
                    systemName: "line.3.horizontal.decrease.circle",
                    message: "Try another title, domain, or tag."
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(filteredLaterItems) { item in
                        LaterPageRow(item: item) {
                            onOpenLater(item)
                        } onRemove: {
                            onRemoveLater(item)
                        } onUpdateTags: { tags in
                            onUpdateLaterTags(item, tags)
                        }
                    }
                }
            }
        }
    }

    private var filteredLaterItems: [LaterItem] {
        let query = laterSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return laterItems
        }

        return laterItems.filter { item in
            item.matchesSearch(query)
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeading(title: "Recent Pages", subtitle: "\(recentPages.count) local")
                Spacer()
                Button("Clear") {
                    onClear()
                }
                .buttonStyle(.link)
            }

            VStack(spacing: 8) {
                ForEach(recentPages) { item in
                    RecentPageRow(item: item) {
                        onOpen(item)
                    }
                }
            }
        }
    }
}

struct QuoteSourceGroup: Identifiable {
    var id: String { url.absoluteString }
    var url: URL
    var title: String
    var siteName: String?
    var latestSavedAt: Date
    var items: [QuoteItem]
}

struct PlainNewsStartRow: View {
    var onOpen: () -> Void

    var body: some View {
        Button {
            onOpen()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.accentColor.opacity(0.1))
                    Image(systemName: "newspaper")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.tint)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Plain News")
                        .foregroundStyle(.primary)
                        .font(.headline)
                    Text("The news you care about")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.38), lineWidth: 1)
        }
        .pointingHandCursor()
    }
}

struct QuoteLibraryStartRow: View {
    var quoteItems: [QuoteItem]
    var onOpen: () -> Void

    private var subtitle: String {
        guard !quoteItems.isEmpty else {
            return "0 saved"
        }
        return "\(quoteItems.count) saved"
    }

    var body: some View {
        Button {
            onOpen()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.accentColor.opacity(0.1))
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.tint)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Quotes")
                        .foregroundStyle(.primary)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.38), lineWidth: 1)
        }
        .pointingHandCursor()
    }
}

struct QuotesLibraryView: View {
    var quoteItems: [QuoteItem]
    var topChromeInset: CGFloat
    var onOpenQuoteSource: (QuoteItem) -> Void
    var onCopyQuote: (QuoteItem) -> Void
    var onRemoveQuote: (QuoteItem) -> Void
    var onUpdateQuoteMetadata: (QuoteItem, String?, [String]) -> Void
    var onExportQuotes: () -> Void
    var onClearQuotes: () -> Void

    @State private var searchText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Quotes")
                            .font(.system(size: 42, weight: .semibold, design: .serif))
                        Text(librarySubtitle)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Export") {
                        onExportQuotes()
                    }
                    .buttonStyle(.link)
                    .disabled(quoteItems.isEmpty)

                    Button("Clear") {
                        onClearQuotes()
                    }
                    .buttonStyle(.link)
                    .disabled(quoteItems.isEmpty)
                }

                if quoteItems.isEmpty {
                    EmptyQuotesLibraryView()
                } else {
                    LibrarySearchField(
                        placeholder: "Search quotes, notes, tags, or sources",
                        text: $searchText
                    )

                    if filteredQuoteItems.isEmpty {
                        EmptyFilteredLibraryView(
                            title: "No matching quotes",
                            systemName: "line.3.horizontal.decrease.circle",
                            message: "Try another word, source, note, or tag."
                        )
                    } else {
                        VStack(spacing: 16) {
                            ForEach(filteredQuoteItems) { item in
                                QuoteReadingCard(item: item) {
                                    onOpenQuoteSource(item)
                                } onCopy: {
                                    onCopyQuote(item)
                                } onRemove: {
                                    onRemoveQuote(item)
                                } onUpdateMetadata: { note, tags in
                                    onUpdateQuoteMetadata(item, note, tags)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 840, alignment: .leading)
            .padding(.horizontal, 42)
            .padding(.top, 56 + topChromeInset)
            .padding(.bottom, 56)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(StartBackground())
    }

    private var librarySubtitle: String {
        guard !quoteItems.isEmpty else {
            return "Saved passages will appear here."
        }
        return "\(quoteItems.count) saved from \(sourceCount) source\(sourceCount == 1 ? "" : "s")"
    }

    private var sortedQuoteItems: [QuoteItem] {
        quoteItems.sorted { $0.savedAt > $1.savedAt }
    }

    private var filteredQuoteItems: [QuoteItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return sortedQuoteItems
        }

        return sortedQuoteItems.filter { item in
            item.matchesSearch(query)
        }
    }

    private var sourceCount: Int {
        Set(quoteItems.map(\.sourceURL)).count
    }
}

struct LibrarySearchField: View {
    var placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.subheadline.weight(.medium))

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .help("Clear Search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.38), lineWidth: 1)
        }
    }
}

struct EmptyFilteredLibraryView: View {
    var title: String
    var systemName: String
    var message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemName)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        }
    }
}

struct EmptyQuotesLibraryView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.1))
                Image(systemName: "quote.bubble")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.tint)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text("No quotes yet")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Saved passages from readable pages will collect here by URL and time.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 176, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        }
    }
}

struct StartBackground: View {
    var body: some View {
        Color(nsColor: .textBackgroundColor)
            .ignoresSafeArea()
    }
}

struct PlainMarkView: View {
    var size: CGFloat
    var iconSize: CGFloat

    var body: some View {
        Group {
            if let appIcon = Self.appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFit()
            } else {
                fallbackMark
            }
        }
        .frame(width: size, height: size)
    }

    private var fallbackMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.12))
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(.tint)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)
        }
    }

    private static let appIcon: NSImage? = {
        if let image = NSImage(named: "AppIcon") {
            return image
        }

        if let bundleIconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: bundleIconURL) {
            return image
        }

        let repoIconURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("packaging/AppIcon.icns")
        return NSImage(contentsOf: repoIconURL)
    }()
}

struct SectionHeading: View {
    var title: String
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

struct FirstRunPlainNote: View {
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PlainMarkView(size: 38, iconSize: 17)

            VStack(alignment: .leading, spacing: 6) {
                Text("Start with a link.")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Search or paste a URL above. Save a page to Later when you want a small trail back.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
            .hoverIconButton(size: 26, cornerRadius: 7)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
        }
    }
}

struct EmptyRecentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.1))
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.tint)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text("No pages yet")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Search or paste a link above to open a quieter version of the page.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 176, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.38), lineWidth: 1)
        }
    }
}

struct RecentPageRow: View {
    var item: HistoryItem
    var onOpen: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button {
            onOpen()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.accentColor.opacity(0.1))
                    Image(systemName: "doc.text")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.tint)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title ?? item.url.absoluteString)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Text(item.url.host(percentEncoded: false) ?? item.url.absoluteString)
                            .lineLimit(1)
                        Text(item.visitedAt.formatted(date: .abbreviated, time: .shortened))
                            .lineLimit(1)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(isHovering ? 0.6 : 0.38), lineWidth: 1)
        }
        .shadow(color: .black.opacity(isHovering ? 0.06 : 0), radius: 10, y: 4)
        .pointingHandCursor()
        .onHover { isHovering = $0 }
    }

    private var rowBackground: Color {
        if isHovering {
            return Color.accentColor.opacity(0.075)
        }
        return Color(nsColor: .controlBackgroundColor).opacity(0.72)
    }
}

struct LaterPageRow: View {
    var item: LaterItem
    var onOpen: () -> Void
    var onRemove: () -> Void
    var onUpdateTags: ([String]) -> Void = { _ in }

    @State private var isHovering = false
    @State private var tagsText = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    onOpen()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color.accentColor.opacity(0.1))
                            Image(systemName: "bookmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.tint)
                        }
                        .frame(width: 36, height: 36)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title ?? item.url.absoluteString)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            HStack(spacing: 8) {
                                Text(item.url.host(percentEncoded: false) ?? item.url.absoluteString)
                                    .lineLimit(1)
                                Text(item.addedAt.formatted(date: .abbreviated, time: .shortened))
                                    .lineLimit(1)
                                if let lastReadAt = item.lastReadAt {
                                    Text("read \(lastReadAt.formatted(date: .abbreviated, time: .omitted))")
                                        .lineLimit(1)
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.leading, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .pointingHandCursor()

                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Remove from Later")
                .hoverIconButton(size: 28, cornerRadius: 7, isDestructive: true)
                .padding(.trailing, 8)
            }

            VStack(alignment: .leading, spacing: 8) {
                LaterProgressBar(progress: item.readingProgress)

                LibraryTagEditor(tags: item.tags, text: $tagsText) {
                    onUpdateTags(QuoteItem.normalizedTags([tagsText]))
                }
            }
            .padding(.leading, 60)
            .padding(.trailing, 12)
            .padding(.bottom, 10)
        }
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(isHovering ? 0.6 : 0.38), lineWidth: 1)
        }
        .shadow(color: .black.opacity(isHovering ? 0.06 : 0), radius: 10, y: 4)
        .onHover { isHovering = $0 }
        .onAppear {
            tagsText = item.tags.joined(separator: ", ")
        }
        .onChange(of: item.tags) { _, tags in
            tagsText = tags.joined(separator: ", ")
        }
    }

    private var rowBackground: Color {
        if isHovering {
            return Color.accentColor.opacity(0.075)
        }
        return Color(nsColor: .controlBackgroundColor).opacity(0.72)
    }
}

struct QuoteSourceGroupView: View {
    var group: QuoteSourceGroup
    var onOpenSource: (QuoteItem) -> Void
    var onCopy: (QuoteItem) -> Void
    var onRemove: (QuoteItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(group.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(group.siteName ?? group.url.host(percentEncoded: false) ?? group.url.absoluteString)
                        Text("\(group.items.count) quote\(group.items.count == 1 ? "" : "s")")
                        Text(group.latestSavedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                Spacer()

                Button {
                    if let first = group.items.first {
                        onOpenSource(first)
                    }
                } label: {
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Open Source")
                .hoverIconButton(size: 28, cornerRadius: 7)
            }

            VStack(spacing: 8) {
                ForEach(group.items) { item in
                    QuoteReadingCard(item: item) {
                        onOpenSource(item)
                    } onCopy: {
                        onCopy(item)
                    } onRemove: {
                        onRemove(item)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.38), lineWidth: 1)
        }
    }
}

struct LaterProgressBar: View {
    var progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(nsColor: .separatorColor).opacity(0.32))
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor.opacity(0.55))
                    .frame(width: max(0, proxy.size.width * LaterItem.clampedProgress(progress)))
            }
        }
        .frame(height: 4)
        .accessibilityLabel("Reading progress \(Int(LaterItem.clampedProgress(progress) * 100)) percent")
    }
}

struct LibraryTagEditor: View {
    var tags: [String]
    @Binding var text: String
    var onSave: () -> Void

    @State private var isEditing = false

    var body: some View {
        Group {
            if isEditing {
                editRow
            } else {
                displayRow
            }
        }
    }

    private var displayRow: some View {
        HStack(spacing: 8) {
            if tags.isEmpty {
                Button {
                    isEditing = true
                } label: {
                    Label("Add tags", systemImage: "tag")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
            } else {
                QuoteTagChips(tags: tags)
            }

            Spacer(minLength: 8)

            Button {
                isEditing = true
            } label: {
                Image(systemName: tags.isEmpty ? "plus" : "pencil")
                    .font(.caption.weight(.bold))
            }
            .buttonStyle(.plain)
            .help(tags.isEmpty ? "Add Tags" : "Edit Tags")
            .hoverIconButton(size: 24, cornerRadius: 6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.62), in: RoundedRectangle(cornerRadius: 7))
    }

    private var editRow: some View {
        HStack(spacing: 8) {
            TextField("Tags, comma separated", text: $text)
                .textFieldStyle(.plain)
                .font(.caption.weight(.medium))
                .onSubmit {
                    save()
                }

            Button {
                save()
            } label: {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
            }
            .buttonStyle(.plain)
            .help("Save Tags")
            .hoverIconButton(size: 24, cornerRadius: 6)

            Button {
                text = tags.joined(separator: ", ")
                isEditing = false
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
            }
            .buttonStyle(.plain)
            .help("Cancel")
            .hoverIconButton(size: 24, cornerRadius: 6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.62), in: RoundedRectangle(cornerRadius: 7))
    }

    private func save() {
        onSave()
        isEditing = false
    }
}

private extension LaterItem {
    func matchesSearch(_ query: String) -> Bool {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else {
            return true
        }

        let haystack = [
            title ?? "",
            url.absoluteString,
            url.host(percentEncoded: false) ?? "",
            tags.joined(separator: " ")
        ]
            .joined(separator: " ")
            .lowercased()

        return haystack.contains(normalizedQuery)
    }
}

struct QuoteReadingCard: View {
    var item: QuoteItem
    var onOpenSource: () -> Void
    var onCopy: () -> Void
    var onRemove: () -> Void
    var onUpdateMetadata: (String?, [String]) -> Void = { _, _ in }

    @State private var isHovering = false
    @State private var isMetadataExpanded = false
    @State private var noteText = ""
    @State private var tagsText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Text("“")
                    .font(.system(size: 42, weight: .regular, design: .serif))
                    .foregroundStyle(.tertiary)
                    .frame(width: 22, alignment: .leading)
                    .padding(.top, -8)

                VStack(alignment: .leading, spacing: 13) {
                    ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                        if paragraph == "[...]" {
                            Text("[...]")
                                .font(.system(size: 16, weight: .regular, design: .serif))
                                .italic()
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        } else {
                            Text(displayText(for: paragraph, at: index))
                                .font(.system(size: 19, weight: .regular, design: .serif))
                                .foregroundStyle(.primary)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()
                .opacity(0.45)

            LibraryTagEditor(tags: item.tags, text: $tagsText) {
                saveTags()
            }

            DisclosureGroup(isExpanded: $isMetadataExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $noteText)
                        .font(.system(size: 13))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 58, maxHeight: 82)
                        .padding(7)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.64), in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(nsColor: .separatorColor).opacity(0.34), lineWidth: 1)
                        }

                    HStack {
                        Spacer()

                        Button {
                            saveNote()
                        } label: {
                            Label("Save note", systemImage: "checkmark")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Save Note")
                    }
                }
                .padding(.top, 8)
            } label: {
                Label(noteLabel, systemImage: "note.text")
                    .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            }

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.sourceTitle ?? item.sourceURL.absoluteString)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(item.siteName ?? item.sourceURL.host(percentEncoded: false) ?? item.sourceURL.absoluteString)
                        Text(item.savedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                Spacer()

                Button {
                    onCopy()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help("Copy Quote")
                .hoverIconButton(size: 26, cornerRadius: 7)

                Button {
                    onOpenSource()
                } label: {
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help("Open Source")
                .hoverIconButton(size: 26, cornerRadius: 7)

                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help("Remove Quote")
                .hoverIconButton(size: 26, cornerRadius: 7, isDestructive: true)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isHovering ? Color.accentColor.opacity(0.04) : Color(nsColor: .textBackgroundColor).opacity(0.72),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(isHovering ? 0.46 : 0.24), lineWidth: 1)
        }
        .onHover { isHovering = $0 }
        .onAppear {
            syncMetadataFields()
        }
        .onChange(of: item.id) { _, _ in
            syncMetadataFields()
        }
        .onChange(of: item.note) { _, note in
            noteText = note ?? ""
        }
        .onChange(of: item.tags) { _, tags in
            tagsText = tags.joined(separator: ", ")
        }
    }

    private var paragraphs: [String] {
        let paragraphBreak = "\u{2029}"
        let normalized = item.text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "[ \\t\\f\\v]*\\n[ \\t\\f\\v]*\\n+[ \\t\\f\\v]*", with: paragraphBreak, options: .regularExpression)
        let values = normalized
            .components(separatedBy: paragraphBreak)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return values.isEmpty ? [item.text] : values
    }

    private func displayText(for paragraph: String, at index: Int) -> String {
        index == paragraphs.count - 1 ? "\(paragraph)”" : paragraph
    }

    private var hasNote: Bool {
        item.note?.isEmpty == false
    }

    private var noteLabel: String {
        if hasNote {
            return "Note"
        }
        return "Add note"
    }

    private func syncMetadataFields() {
        noteText = item.note ?? ""
        tagsText = item.tags.joined(separator: ", ")
    }

    private func saveNote() {
        let note = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        onUpdateMetadata(note.isEmpty ? nil : note, item.tags)
    }

    private func saveTags() {
        onUpdateMetadata(item.note, QuoteItem.normalizedTags([tagsText]))
    }
}

struct QuoteTagChips: View {
    var tags: [String]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(tags.prefix(4)), id: \.self) { tag in
                Text("#\(tag)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.82), in: RoundedRectangle(cornerRadius: 5))
            }

            if tags.count > 4 {
                Text("+\(tags.count - 4)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private extension QuoteItem {
    func matchesSearch(_ query: String) -> Bool {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else {
            return true
        }

        let haystack = [
            text,
            sourceTitle ?? "",
            siteName ?? "",
            sourceURL.absoluteString,
            note ?? "",
            tags.joined(separator: " ")
        ]
            .joined(separator: " ")
            .lowercased()

        return haystack.contains(normalizedQuery)
    }
}

struct LaterPopoverPanel: View {
    var items: [LaterItem]
    var onOpen: (LaterItem) -> Void
    var onRemove: (LaterItem) -> Void
    var onUpdateTags: (LaterItem, [String]) -> Void
    var onExport: () -> Void
    var onImport: () -> Void
    var onClear: () -> Void

    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Later", systemImage: "list.bullet")
                        .font(.headline)
                    Text("Choose, tag, or import saved pages.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Import") {
                    onImport()
                }
                .buttonStyle(.link)

                Button("Export") {
                    onExport()
                }
                .buttonStyle(.link)
                .disabled(items.isEmpty)

                Button("Clear") {
                    onClear()
                }
                .buttonStyle(.link)
                .disabled(items.isEmpty)
            }

            Divider()

            if !items.isEmpty {
                LibrarySearchField(placeholder: "Search Later", text: $searchText)
            }

            if items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Nothing saved yet")
                        .font(.subheadline.weight(.semibold))
                    Text("Use the bookmark button or Cmd-D to keep the current page here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
                .padding(14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
                }
            } else if filteredItems.isEmpty {
                EmptyFilteredLibraryView(
                    title: "No matching items",
                    systemName: "line.3.horizontal.decrease.circle",
                    message: "Try another title, domain, or tag."
                )
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(filteredItems) { item in
                            LaterPopoverRow(item: item) {
                                onOpen(item)
                            } onRemove: {
                                onRemove(item)
                            } onUpdateTags: { tags in
                                onUpdateTags(item, tags)
                            }
                        }
                    }
                    .padding(.vertical, 1)
                }
                .frame(maxHeight: 360)
            }
        }
        .padding(14)
        .frame(width: 410)
    }

    private var filteredItems: [LaterItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return items
        }

        return items.filter { item in
            item.matchesSearch(query)
        }
    }
}

struct LaterPopoverRow: View {
    var item: LaterItem
    var onOpen: () -> Void
    var onRemove: () -> Void
    var onUpdateTags: ([String]) -> Void = { _ in }

    @State private var isHovering = false
    @State private var tagsText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    onOpen()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title ?? item.url.absoluteString)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Text(item.url.host(percentEncoded: false) ?? item.url.absoluteString)
                            Text(item.addedAt.formatted(date: .abbreviated, time: .shortened))
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointingHandCursor()

                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help("Remove from Later")
                .hoverIconButton(size: 26, cornerRadius: 7, isDestructive: true)
            }

            LaterProgressBar(progress: item.readingProgress)

            LibraryTagEditor(tags: item.tags, text: $tagsText) {
                onUpdateTags(QuoteItem.normalizedTags([tagsText]))
            }
        }
        .padding(.leading, 11)
        .padding(.trailing, 6)
        .padding(.vertical, 9)
        .background(
            isHovering ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor).opacity(0.68),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(isHovering ? 0.58 : 0.36), lineWidth: 1)
        }
        .onHover { isHovering = $0 }
        .onAppear {
            tagsText = item.tags.joined(separator: ", ")
        }
        .onChange(of: item.tags) { _, tags in
            tagsText = tags.joined(separator: ", ")
        }
    }
}

struct LoadingView: View {
    var url: URL?

    var body: some View {
        VStack(spacing: 18) {
            PlainMarkView(size: 72, iconSize: 30)
                .overlay {
                    ProgressView()
                        .controlSize(.small)
                        .padding(5)
                        .background(.regularMaterial, in: Circle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }

            VStack(spacing: 5) {
                Text("Opening page")
                    .font(.title3.weight(.semibold))
                if let host = url?.host(percentEncoded: false) {
                    Text(host)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(StartBackground())
    }
}

struct FailureView: View {
    var failure: ReaderFailure
    var onOpenInDefaultBrowser: () -> Void
    var onReportIssue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red.opacity(0.1))
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.red)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 8) {
                Text(failure.title)
                    .font(.title2.weight(.semibold))
                Text(failure.message)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if failure.url != nil {
                    Text("If this should be a readable page, report it and include what looked wrong.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let url = failure.url {
                Text(url.absoluteString)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 10) {
                Button {
                    onOpenInDefaultBrowser()
                } label: {
                    Label("Open in Default Browser", systemImage: "globe")
                }
                .disabled(failure.url == nil)

                Button {
                    onReportIssue()
                } label: {
                    Label("Report Page Issue", systemImage: "envelope")
                }
                .disabled(failure.url == nil)
            }

            Spacer()
        }
        .padding(34)
        .frame(maxWidth: 760, maxHeight: .infinity, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(StartBackground())
    }
}
