import AppKit
import PlainCore
import SwiftUI

struct DocumentView: View {
    var document: DocumentModel
    var showsImages: Bool
    var readerSettings: ReaderDisplaySettings
    var selectedFindTarget: DocumentFindTarget?
    var topChromeInset: CGFloat
    var onOpenLink: (URL) -> Void
    var onOpenExternalLink: (URL) -> Void
    var onSaveImage: (ImageRef) -> Void
    var onSaveQuote: (String) -> Void
    var onReportIssue: () -> Void
    var onReadingProgressChange: (Double) -> Void
    var isQuoteSelectionActive: Bool
    var selectedQuoteElementIDs: Set<Int>
    var onSelectQuoteElement: (Int) -> Void
    var onDragSelectQuoteElement: (Int) -> Void

    @State private var readingProgress: Double = 0

    private var contentMaxWidth: CGFloat {
        if document.elements.contains(where: \.isSearchResult) {
            return 860
        }
        return 742
    }

    var body: some View {
        ScrollViewReader { proxy in
            GeometryReader { viewportProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        .id(DocumentFindTarget.header)
                        .findTargetHighlight(selectedFindTarget == .header)

                        ForEach(Array(document.elements.enumerated()), id: \.offset) { index, element in
                            QuoteSelectableElementView(
                                id: index,
                                isEnabled: isQuoteSelectionActive && element.quotePlainText != nil,
                                isSelected: selectedQuoteElementIDs.contains(index),
                                onSelect: onSelectQuoteElement,
                                onDragSelect: onDragSelectQuoteElement
                            ) {
                                DocumentElementView(
                                    element: element,
                                    showsImages: showsImages,
                                    readerSettings: readerSettings,
                                    onOpenLink: onOpenLink,
                                    onOpenExternalLink: onOpenExternalLink,
                                    onSaveImage: onSaveImage,
                                    onSaveQuote: onSaveQuote
                                )
                            }
                            .id(DocumentFindTarget.element(index))
                            .findTargetHighlight(selectedFindTarget == .element(index))
                        }
                    }
                    .background(
                        GeometryReader { contentProxy in
                            Color.clear.preference(
                                key: ReaderScrollMetricsPreferenceKey.self,
                                value: ReaderScrollMetrics(
                                    offset: -contentProxy.frame(in: .named("Plain.ReaderScroll")).minY,
                                    contentHeight: contentProxy.size.height,
                                    viewportHeight: viewportProxy.size.height
                                )
                            )
                        }
                    )
                    .frame(maxWidth: contentMaxWidth, alignment: .leading)
                    .padding(.horizontal, 42)
                    .padding(.top, 50 + topChromeInset)
                    .padding(.bottom, 86)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .coordinateSpace(name: "Plain.ReaderScroll")
                .overlay(alignment: .top) {
                    ReaderProgressLine(progress: readingProgress)
                        .padding(.top, topChromeInset)
                }
                .onPreferenceChange(ReaderScrollMetricsPreferenceKey.self) { metrics in
                    let progress = metrics.progress
                    readingProgress = progress
                    onReadingProgressChange(progress)
                }
            }
            .background(readerBackground)
            .environment(
                \.openURL,
                OpenURLAction { url in
                    onOpenLink(url)
                    return .handled
                }
            )
            .onChange(of: selectedFindTarget) { _, target in
                guard let target else {
                    return
                }

                withAnimation(.easeInOut(duration: 0.18)) {
                    proxy.scrollTo(target, anchor: .center)
                }
            }
        }
    }

    private var readerBackground: some View {
        Color(nsColor: .textBackgroundColor)
            .ignoresSafeArea()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            if showsImages,
               let heroImage = document.heroImage,
               heroImage.localPath != nil {
                ReaderHeroImageView(image: heroImage, onSaveImage: onSaveImage, onOpenExternalLink: onOpenExternalLink)
                    .padding(.bottom, 4)
            }

            VStack(alignment: .leading, spacing: 12) {
                if let host = document.finalURL.host(percentEncoded: false) {
                    SourceLine(host: host, url: document.finalURL)
                }

                Text(document.title ?? document.finalURL.absoluteString)
                    .font(readerSettings.swiftUIFont(size: 45, weight: .bold))
                    .lineSpacing(readerSettings.scaled(5))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            metadata

            if let excerpt = document.excerpt, !excerpt.isEmpty {
                Text(excerpt)
                    .font(readerSettings.swiftUIFont(size: 20.5))
                    .foregroundStyle(.secondary)
                    .lineSpacing(readerSettings.scaled(5.5))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }

            if document.extractionQuality != .strong {
                ExtractionFeedbackPanel(quality: document.extractionQuality, onReportIssue: onReportIssue)
            }

            Divider()
                .padding(.top, 10)
        }
        .padding(.bottom, 10)
    }

    private var estimatedReadingMinutes: Int {
        let wordCount = document.elements
            .compactMap(\.quotePlainText)
            .joined(separator: " ")
            .split(whereSeparator: \.isWhitespace)
            .count
        return max(1, Int(ceil(Double(wordCount) / 225.0)))
    }

    private var metadata: some View {
        ViewThatFits(in: .horizontal) {
            metadataChips
            ScrollView(.horizontal, showsIndicators: false) {
                metadataChips
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var metadataChips: some View {
        HStack(spacing: 8) {
            MetadataChip(text: "\(estimatedReadingMinutes) min read", systemName: "clock")

            if let siteName = document.siteName {
                MetadataChip(text: siteName, systemName: "building.2")
            }

            if let author = document.author {
                MetadataChip(text: author, systemName: "person")
            }

            if let publishedAt = document.publishedAt {
                MetadataChip(
                    text: publishedAt.formatted(date: .abbreviated, time: .omitted),
                    systemName: "calendar"
                )
            }

            if document.extractionQuality == .fallback {
                MetadataChip(text: "Simplified fallback", systemName: "wand.and.stars")
            } else if document.extractionQuality == .weak {
                MetadataChip(text: "Low-confidence extraction", systemName: "exclamationmark.triangle")
            }

            if !showsImages, !document.images.isEmpty {
                MetadataChip(text: "Images hidden", systemName: "photo")
            }
        }
    }
}

private struct ReaderScrollMetrics: Equatable {
    var offset: CGFloat = 0
    var contentHeight: CGFloat = 1
    var viewportHeight: CGFloat = 1

    var progress: Double {
        let scrollableHeight = max(contentHeight - viewportHeight, 1)
        return Double(min(1, max(0, offset / scrollableHeight)))
    }
}

private struct ReaderScrollMetricsPreferenceKey: PreferenceKey {
    static let defaultValue = ReaderScrollMetrics()

    static func reduce(value: inout ReaderScrollMetrics, nextValue: () -> ReaderScrollMetrics) {
        value = nextValue()
    }
}

private struct ReaderProgressLine: View {
    var progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(0.18))
                Rectangle()
                    .fill(Color.accentColor.opacity(0.62))
                    .frame(width: proxy.size.width * min(1, max(0, progress)))
            }
        }
        .frame(height: 2)
        .accessibilityLabel("Reader progress \(Int(min(1, max(0, progress)) * 100)) percent")
    }
}

private struct ExtractionFeedbackPanel: View {
    var quality: ExtractionQuality
    var onReportIssue: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: quality == .weak ? "exclamationmark.triangle" : "wand.and.stars")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(quality == .weak ? Color(nsColor: .systemOrange) : Color.accentColor)
                .frame(width: 30, height: 30)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.82), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text("If the page looks wrong, send a prefilled report so the extractor can learn from this URL.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Button {
                onReportIssue()
            } label: {
                Label("Report", systemImage: "envelope")
            }
            .buttonStyle(.bordered)
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        }
    }

    private var title: String {
        switch quality {
        case .strong:
            return "Extraction looks solid"
        case .fallback:
            return "Simplified fallback extraction"
        case .weak:
            return "Low-confidence extraction"
        }
    }
}

private struct QuoteSelectableElementView<Content: View>: View {
    var id: Int
    var isEnabled: Bool
    var isSelected: Bool
    var onSelect: (Int) -> Void
    var onDragSelect: (Int) -> Void
    @ViewBuilder var content: () -> Content
    @State private var isHovering = false

    var body: some View {
        if isEnabled {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .allowsHitTesting(false)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            .background(
                selectionBackground,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? Color.accentColor.opacity(0.42) : Color(nsColor: .separatorColor).opacity(isHovering ? 0.28 : 0),
                        lineWidth: 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .onTapGesture {
                onSelect(id)
            }
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { _ in
                        onDragSelect(id)
                    }
            )
            .onHover { hovering in
                isHovering = hovering
                if hovering && NSEvent.pressedMouseButtons & 1 == 1 {
                    onDragSelect(id)
                }
            }
        } else {
            content()
        }
    }

    private var selectionBackground: Color {
        if isSelected {
            return Color(nsColor: .selectedTextBackgroundColor).opacity(0.22)
        }
        if isHovering {
            return Color(nsColor: .selectedTextBackgroundColor).opacity(0.08)
        }
        return Color.clear
    }
}

private struct SourceLine: View {
    var host: String
    var url: URL

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "network")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.tint)
            Text(host)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(url.scheme?.uppercased() ?? "WEB")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.7), in: Capsule())
        }
        .textSelection(.enabled)
    }
}

private struct FindTargetHighlightModifier: ViewModifier {
    var isActive: Bool

    func body(content: Content) -> some View {
        content
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.08))
                        .padding(-8)
                }
            }
            .overlay {
                if isActive {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.7), lineWidth: 1.5)
                        .padding(-8)
                }
            }
    }
}

private extension View {
    func findTargetHighlight(_ isActive: Bool) -> some View {
        modifier(FindTargetHighlightModifier(isActive: isActive))
    }
}

private struct MetadataChip: View {
    var text: String
    var systemName: String

    var body: some View {
        Label(text, systemImage: systemName)
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.thinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color(nsColor: .separatorColor).opacity(0.42), lineWidth: 1)
            }
    }
}

private struct DocumentElementView: View {
    var element: DocumentElement
    var showsImages: Bool
    var readerSettings: ReaderDisplaySettings
    var onOpenLink: (URL) -> Void
    var onOpenExternalLink: (URL) -> Void
    var onSaveImage: (ImageRef) -> Void
    var onSaveQuote: (String) -> Void

    var body: some View {
        switch element {
        case .heading(let level, let text):
            HeadingView(level: level, text: text, readerSettings: readerSettings)
        case .paragraph(let inline):
            ParagraphView(
                inline: inline,
                readerSettings: readerSettings,
                onOpenLink: onOpenLink,
                onOpenExternalLink: onOpenExternalLink,
                onSaveQuote: onSaveQuote
            )
        case .searchResult(let result):
            SearchResultView(result: result, readerSettings: readerSettings, onOpenLink: onOpenLink, onOpenExternalLink: onOpenExternalLink)
        case .image(let image):
            if showsImages {
                ReaderImageView(image: image, onSaveImage: onSaveImage, onOpenExternalLink: onOpenExternalLink)
            }
        case .figure(let image, let caption):
            if showsImages {
                ReaderImageView(image: image, caption: caption, onSaveImage: onSaveImage, onOpenExternalLink: onOpenExternalLink)
            }
        case .blockquote(let elements):
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(elements.enumerated()), id: \.offset) { _, child in
                    DocumentElementView(
                        element: child,
                        showsImages: showsImages,
                        readerSettings: readerSettings,
                        onOpenLink: onOpenLink,
                        onOpenExternalLink: onOpenExternalLink,
                        onSaveImage: onSaveImage,
                        onSaveQuote: onSaveQuote
                    )
                }
            }
            .padding(.vertical, 15)
            .padding(.leading, 20)
            .padding(.trailing, 16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor.opacity(0.55))
                    .frame(width: 4)
                    .padding(.vertical, 10)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.32), lineWidth: 1)
            }
        case .list(let ordered, let items):
            VStack(alignment: .leading, spacing: 11) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(ordered ? "\(index + 1)." : "•")
                            .font(readerSettings.swiftUIFont(size: 17, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(item.enumerated()), id: \.offset) { _, child in
                                DocumentElementView(
                                    element: child,
                                    showsImages: showsImages,
                                    readerSettings: readerSettings,
                                    onOpenLink: onOpenLink,
                                    onOpenExternalLink: onOpenExternalLink,
                                    onSaveImage: onSaveImage,
                                    onSaveQuote: onSaveQuote
                                )
                            }
                        }
                    }
                }
            }
        case .codeBlock(_, let code):
            ScrollView(.horizontal) {
                Text(code)
                    .font(.system(size: readerSettings.scaled(14.5), design: .monospaced))
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.82), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.42), lineWidth: 1)
            }
        case .table(let table):
            ReaderTableView(table: table)
        case .horizontalRule:
            Divider()
                .padding(.vertical, 10)
        case .linkPreview(let url, let text):
            LinkPreviewView(url: url, text: text, readerSettings: readerSettings, onOpenLink: onOpenLink, onOpenExternalLink: onOpenExternalLink)
        }
    }
}

private extension DocumentElement {
    var isSearchResult: Bool {
        if case .searchResult = self {
            return true
        }
        return false
    }
}

private struct SearchResultView: View {
    var result: SearchResult
    var readerSettings: ReaderDisplaySettings
    var onOpenLink: (URL) -> Void
    var onOpenExternalLink: (URL) -> Void

    @State private var isHovering = false

    var body: some View {
        Button {
            open(result.url)
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                if let displayURL = result.displayURL {
                    Label(displayURL, systemImage: "link")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(result.title)
                        .font(readerSettings.swiftUIFont(size: 23, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                if let snippet = result.snippet {
                    Text(snippet)
                        .font(readerSettings.swiftUIFont(size: 16))
                        .foregroundStyle(.secondary)
                        .lineSpacing(readerSettings.scaled(3))
                        .lineLimit(3)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .background(rowBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor).opacity(isHovering ? 0.55 : 0.28), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .onHover { isHovering = $0 }
    }

    private var rowBackground: Color {
        if isHovering {
            return Color.accentColor.opacity(0.08)
        }
        return Color(nsColor: .controlBackgroundColor).opacity(0.36)
    }

    private func open(_ url: URL) {
        if NSApp.currentEvent?.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command) == true {
            onOpenExternalLink(url)
        } else {
            onOpenLink(url)
        }
    }
}

private struct LinkPreviewView: View {
    var url: URL
    var text: String?
    var readerSettings: ReaderDisplaySettings
    var onOpenLink: (URL) -> Void
    var onOpenExternalLink: (URL) -> Void

    @State private var isHovering = false

    var body: some View {
        Button {
            open(url)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.12))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.tint)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(text ?? url.absoluteString)
                        .font(readerSettings.swiftUIFont(size: 16.5, weight: .semibold))
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                    Text(url.host(percentEncoded: false) ?? url.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .background(
                isHovering ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor).opacity(0.55),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.38), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .onHover { isHovering = $0 }
    }

    private func open(_ url: URL) {
        if NSApp.currentEvent?.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command) == true {
            onOpenExternalLink(url)
        } else {
            onOpenLink(url)
        }
    }
}

private struct HeadingView: View {
    var level: Int
    var text: String
    var readerSettings: ReaderDisplaySettings

    var body: some View {
        Text(text)
            .font(font)
            .lineSpacing(readerSettings.scaled(level <= 2 ? 3 : 2))
            .padding(.top, level <= 2 ? 22 : 12)
            .padding(.bottom, level <= 2 ? 2 : 0)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }

    private var font: Font {
        switch level {
        case 1:
            return readerSettings.swiftUIFont(size: 33, weight: .bold)
        case 2:
            return readerSettings.swiftUIFont(size: 26, weight: .semibold)
        case 3:
            return readerSettings.swiftUIFont(size: 22, weight: .semibold)
        default:
            return readerSettings.swiftUIFont(size: 18, weight: .semibold)
        }
    }
}

private struct ReaderHeroImageView: View {
    var image: ImageRef
    var onSaveImage: (ImageRef) -> Void
    var onOpenExternalLink: (URL) -> Void

    var body: some View {
        if let localPath = image.localPath,
           let nsImage = NSImage(contentsOf: localPath) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 260)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
                .imageActions(image: image, onSaveImage: onSaveImage, onOpenExternalLink: onOpenExternalLink)
        }
    }
}

private struct ReaderImageView: View {
    var image: ImageRef
    var caption: String?
    var onSaveImage: (ImageRef) -> Void
    var onOpenExternalLink: (URL) -> Void

    init(
        image: ImageRef,
        caption: String? = nil,
        onSaveImage: @escaping (ImageRef) -> Void,
        onOpenExternalLink: @escaping (URL) -> Void
    ) {
        self.image = image
        self.caption = caption ?? image.caption
        self.onSaveImage = onSaveImage
        self.onOpenExternalLink = onOpenExternalLink
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let localPath = image.localPath,
               let nsImage = NSImage(contentsOf: localPath) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.08), radius: 14, y: 5)
                    .imageActions(image: image, onSaveImage: onSaveImage, onOpenExternalLink: onOpenExternalLink)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "photo")
                        .font(.system(size: 22, weight: .semibold))
                    Text(image.alt ?? image.sourceURL.absoluteString)
                        .font(.caption)
                        .lineLimit(2)
                }
                .foregroundStyle(.secondary)
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.42), lineWidth: 1)
                }
                .imageActions(image: image, onSaveImage: onSaveImage, onOpenExternalLink: onOpenExternalLink)
            }

            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 6)
    }
}

private extension View {
    func imageActions(
        image: ImageRef,
        onSaveImage: @escaping (ImageRef) -> Void,
        onOpenExternalLink: @escaping (URL) -> Void
    ) -> some View {
        contextMenu {
            Button("Save Image As...") {
                onSaveImage(image)
            }
            .disabled(image.localPath == nil)

            Button("Open Image in Default Browser") {
                onOpenExternalLink(image.sourceURL)
            }
        }
    }
}

private struct ReaderTableView: View {
    var table: SimpleTable

    var body: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 11) {
                if !table.headers.isEmpty {
                    GridRow {
                        ForEach(Array(table.headers.enumerated()), id: \.offset) { _, header in
                            Text(header)
                                .font(.headline.weight(.semibold))
                                .textSelection(.enabled)
                        }
                    }
                    Divider()
                        .gridCellUnsizedAxes(.horizontal)
                }

                ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            Text(cell)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.42), lineWidth: 1)
        }
    }
}
