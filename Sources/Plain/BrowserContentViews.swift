import AppKit
import PlainCore
import SwiftUI

struct StartView: View {
    var recentPages: [HistoryItem]
    var laterItems: [LaterItem]
    var showsWelcome: Bool
    var topChromeInset: CGFloat
    var onOpen: (HistoryItem) -> Void
    var onOpenLater: (LaterItem) -> Void
    var onRemoveLater: (LaterItem) -> Void
    var onExportLater: () -> Void
    var onClearLater: () -> Void
    var onClear: () -> Void
    var onDismissWelcome: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                brandHeader

                if showsWelcome {
                    FirstRunPlainNote(onDismiss: onDismissWelcome)
                }

                if !laterItems.isEmpty {
                    laterSection
                }

                if recentPages.isEmpty && laterItems.isEmpty {
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
                Button("Export") {
                    onExportLater()
                }
                .buttonStyle(.link)
                Button("Clear") {
                    onClearLater()
                }
                .buttonStyle(.link)
            }

            VStack(spacing: 8) {
                ForEach(laterItems) { item in
                    LaterPageRow(item: item) {
                        onOpenLater(item)
                    } onRemove: {
                        onRemoveLater(item)
                    }
                }
            }
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

    @State private var isHovering = false

    var body: some View {
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
                .padding(.vertical, 12)
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
            .padding(.trailing, 8)
        }
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(isHovering ? 0.6 : 0.38), lineWidth: 1)
        }
        .shadow(color: .black.opacity(isHovering ? 0.06 : 0), radius: 10, y: 4)
        .onHover { isHovering = $0 }
    }

    private var rowBackground: Color {
        if isHovering {
            return Color.accentColor.opacity(0.075)
        }
        return Color(nsColor: .controlBackgroundColor).opacity(0.72)
    }
}

struct LaterPopoverPanel: View {
    var items: [LaterItem]
    var onOpen: (LaterItem) -> Void
    var onRemove: (LaterItem) -> Void
    var onExport: () -> Void
    var onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Later", systemImage: "list.bullet")
                        .font(.headline)
                    Text("Choose a saved page to open it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

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
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(items) { item in
                            LaterPopoverRow(item: item) {
                                onOpen(item)
                            } onRemove: {
                                onRemove(item)
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
}

struct LaterPopoverRow: View {
    var item: LaterItem
    var onOpen: () -> Void
    var onRemove: () -> Void

    @State private var isHovering = false

    var body: some View {
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
