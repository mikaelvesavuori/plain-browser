import PlainCore
import SwiftUI

enum PlainNewsDigestOrganization: String, CaseIterable, Hashable {
    case source
    case time

    var label: String {
        switch self {
        case .source:
            return "Source"
        case .time:
            return "Time"
        }
    }
}

struct PlainNewsDigestItemsView: View {
    var organization: PlainNewsDigestOrganization
    var presentation: PlainNewsDigestPresentation
    var onOpenItem: (PlainNewsDigestItem) -> Void
    var onSaveItemForLater: (PlainNewsDigestItem) -> Void

    init(
        digest: PlainNewsDigest,
        organization: PlainNewsDigestOrganization,
        savedItemURLStrings: Set<String>,
        onOpenItem: @escaping (PlainNewsDigestItem) -> Void,
        onSaveItemForLater: @escaping (PlainNewsDigestItem) -> Void
    ) {
        self.organization = organization
        self.presentation = PlainNewsDigestPresentation(
            digest: digest,
            savedItemURLStrings: savedItemURLStrings
        )
        self.onOpenItem = onOpenItem
        self.onSaveItemForLater = onSaveItemForLater
    }

    var body: some View {
        switch organization {
        case .time:
            ForEach(presentation.timeOrderedItems) { item in
                digestRow(for: item, showsSourceName: true)
            }
        case .source:
            LazyVStack(spacing: 8) {
                ForEach(presentation.sourceEntries) { entry in
                    switch entry.kind {
                    case .header(let group, let isFirst):
                        sourceHeader(for: group, isFirst: isFirst)
                    case .item(let item):
                        digestRow(for: item, showsSourceName: false)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sourceHeader(
        for group: PlainNewsDigestSourceGroup,
        isFirst: Bool
    ) -> some View {
        PlainNewsDigestSourceHeaderView(group: group)
            .padding(.top, isFirst ? 4 : 18)
    }

    private func digestRow(
        for item: PlainNewsDigestPresentedItem,
        showsSourceName: Bool
    ) -> some View {
        PlainNewsDigestRow(
            presentedItem: item,
            showsSourceName: showsSourceName
        ) {
            onOpenItem(item.item)
        } onSaveForLater: {
            onSaveItemForLater(item.item)
        }
        .id(item.id)
    }
}

struct PlainNewsDigestPresentation {
    var timeOrderedItems: [PlainNewsDigestPresentedItem]
    var sourceGroups: [PlainNewsDigestSourceGroup]
    var sourceEntries: [PlainNewsDigestSourceEntry]

    init(digest: PlainNewsDigest, savedItemURLStrings: Set<String>) {
        let items = digest.items.map { item in
            PlainNewsDigestPresentedItem(
                item: item,
                isSavedForLater: savedItemURLStrings.contains(
                    PlainNewsArticle.normalizedURLString(item.article.url)
                )
            )
        }

        self.timeOrderedItems = Self.timeOrderedItems(items)
        let sourceGroups = Self.sourceGroups(from: items)
        self.sourceGroups = sourceGroups
        self.sourceEntries = Self.sourceEntries(from: sourceGroups)
    }

    private static func timeOrderedItems(
        _ items: [PlainNewsDigestPresentedItem]
    ) -> [PlainNewsDigestPresentedItem] {
        items.sorted { left, right in
            left.articleDate > right.articleDate
        }
    }

    private static func sourceGroups(
        from items: [PlainNewsDigestPresentedItem]
    ) -> [PlainNewsDigestSourceGroup] {
        Dictionary(grouping: items) { item in
            item.item.article.sourceID
        }
        .map { sourceID, values in
            let sortedItems = timeOrderedItems(values)
            return PlainNewsDigestSourceGroup(
                id: sourceID,
                sourceName: sortedItems.first?.item.article.sourceName ?? "Source",
                items: sortedItems
            )
        }
        .sorted { left, right in
            let comparison = left.sourceName.localizedStandardCompare(right.sourceName)
            if comparison == .orderedSame {
                return (left.items.first?.articleDate ?? .distantPast) > (right.items.first?.articleDate ?? .distantPast)
            }
            return comparison == .orderedAscending
        }
    }

    private static func sourceEntries(
        from groups: [PlainNewsDigestSourceGroup]
    ) -> [PlainNewsDigestSourceEntry] {
        groups.enumerated().flatMap { index, group in
            [
                PlainNewsDigestSourceEntry(kind: .header(group, isFirst: index == 0))
            ] + group.items.map { item in
                PlainNewsDigestSourceEntry(kind: .item(item))
            }
        }
    }
}

struct PlainNewsDigestPresentedItem: Identifiable {
    var item: PlainNewsDigestItem
    var isSavedForLater: Bool

    var id: String {
        item.id
    }

    var articleDate: Date {
        item.article.publishedAt ?? item.article.observedAt
    }
}

struct PlainNewsDigestSourceGroup: Identifiable {
    var id: UUID
    var sourceName: String
    var items: [PlainNewsDigestPresentedItem]
}

struct PlainNewsDigestSourceEntry: Identifiable {
    enum Kind {
        case header(PlainNewsDigestSourceGroup, isFirst: Bool)
        case item(PlainNewsDigestPresentedItem)
    }

    var kind: Kind

    var id: String {
        switch kind {
        case .header(let group, _):
            return "source-\(group.id.uuidString)"
        case .item(let item):
            return item.id
        }
    }
}

private struct PlainNewsDigestSourceHeaderView: View {
    var group: PlainNewsDigestSourceGroup

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Label(group.sourceName, systemImage: "tray.full")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text("\(group.items.count)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .padding(.horizontal, 2)
    }
}

private struct PlainNewsDigestRow: View {
    var presentedItem: PlainNewsDigestPresentedItem
    var showsSourceName = true
    var onOpen: () -> Void
    var onSaveForLater: () -> Void

    @State private var isHovering = false

    private var item: PlainNewsDigestItem {
        presentedItem.item
    }

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            VStack(alignment: .leading, spacing: 7) {
                if showsSourceName || item.article.publishedAt != nil {
                    HStack(spacing: 8) {
                        if showsSourceName {
                            Text(item.article.sourceName)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        if let publishedAt = item.article.publishedAt {
                            Text(publishedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text(item.article.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(item.assessment.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onOpen()
                }
                .pointingHandCursor()
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Button {
                    onSaveForLater()
                } label: {
                    Image(systemName: presentedItem.isSavedForLater ? "checkmark" : "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(presentedItem.isSavedForLater ? Color.green : Color(nsColor: .secondaryLabelColor))
                        .frame(width: 28, height: 28)
                        .background(Color(nsColor: .textBackgroundColor).opacity(0.86), in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .disabled(presentedItem.isSavedForLater)
                .help(presentedItem.isSavedForLater ? "Saved to Later" : "Save to Later")
                .hoverIconButton(size: 28, cornerRadius: 7)

                Button {
                    onOpen()
                } label: {
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color(nsColor: .textBackgroundColor).opacity(0.86), in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .help("Open")
                .hoverIconButton(size: 28, cornerRadius: 7)
            }
            .padding(.top, 1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isHovering ? Color.accentColor.opacity(0.07) : Color(nsColor: .controlBackgroundColor).opacity(0.72),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(isHovering ? 0.6 : 0.38), lineWidth: 1)
        }
        .shadow(color: .black.opacity(isHovering ? 0.06 : 0), radius: 10, y: 4)
        .onHover { isHovering = $0 }
    }
}
