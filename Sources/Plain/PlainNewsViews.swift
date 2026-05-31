import PlainCore
import SwiftUI

private enum PlainNewsSourcePanelTab: String, CaseIterable {
    case browse
    case yourSources
    case addSource

    var label: String {
        switch self {
        case .browse:
            return "Sources"
        case .yourSources:
            return "Yours"
        case .addSource:
            return "Add"
        }
    }

    var systemName: String {
        switch self {
        case .browse:
            return "tray.full"
        case .yourSources:
            return "checklist"
        case .addSource:
            return "plus.circle"
        }
    }
}

struct PlainNewsView: View {
    var sources: [PlainNewsSource]
    @Binding var interestProfile: String
    @Binding var window: PlainNewsWindow
    @Binding var limitsResults: Bool
    @Binding var resultLimit: Int
    var digest: PlainNewsDigest?
    var progress: PlainNewsProgress?
    var errorMessage: String?
    var aiStatus: PlainNewsAIStatus
    var isRunning: Bool
    var topChromeInset: CGFloat
    var isItemSavedForLater: (PlainNewsDigestItem) -> Bool
    var onAddSource: (String, String, PlainNewsSourceKind, [PlainNewsCategory]) -> Void
    var onAddPreset: (PlainNewsSource) -> Void
    var onToggleSource: (PlainNewsSource) -> Void
    var onRemoveSource: (PlainNewsSource) -> Void
    var onRun: () -> Void
    var onClearDigest: () -> Void
    var onOpenItem: (PlainNewsDigestItem) -> Void
    var onSaveItemForLater: (PlainNewsDigestItem) -> Void

    @State private var sourceName = ""
    @State private var sourceURL = ""
    @State private var sourceKind = PlainNewsSourceKind.rss
    @State private var sourceCategories: Set<PlainNewsCategory> = [.world]
    @State private var selectedSourceCategory: PlainNewsCategory?
    @State private var selectedPresetCategory: PlainNewsCategory?
    @State private var sourceSearch = ""
    @State private var sourcePanelTab = PlainNewsSourcePanelTab.browse

    private var enabledSourceCount: Int {
        sources.filter(\.isEnabled).count
    }

    private var filteredSources: [PlainNewsSource] {
        PlainNewsSource.sortedByDisplayName(sources.filter { source in
            source.belongs(to: selectedSourceCategory) && source.matchesSearch(sourceSearch)
        })
    }

    private var filteredPresetSources: [PlainNewsSource] {
        PlainNewsSource.sortedByDisplayName(PlainNewsPresetSources.sources.filter { source in
            source.belongs(to: selectedPresetCategory) && source.matchesSearch(sourceSearch)
        })
    }

    private var hasRunSurface: Bool {
        digest != nil || progress != nil || isRunning
    }

    private var windowModeBinding: Binding<PlainNewsWindow.Mode> {
        Binding(
            get: { window.mode },
            set: { window = window.withMode($0) }
        )
    }

    private var rollingDaysSliderBinding: Binding<Double> {
        Binding(
            get: { Double(window.rollingDays) },
            set: { window = window.withRollingDays(Int($0.rounded())) }
        )
    }

    private var rollingDaysStepperBinding: Binding<Int> {
        Binding(
            get: { window.rollingDays },
            set: { window = window.withRollingDays($0) }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            sourcePanel
                .frame(width: 370)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.62))
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor).opacity(0.45))
                        .frame(width: 1)
                }

            digestPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var sourcePanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Source View", selection: $sourcePanelTab) {
                        ForEach(PlainNewsSourcePanelTab.allCases, id: \.self) { tab in
                            Label(tab.label, systemImage: tab.systemName).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    if let sourcePanelSubtitle {
                        Text(sourcePanelSubtitle)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                switch sourcePanelTab {
                case .browse:
                    sourceLibraryPanel
                case .yourSources:
                    yourSourcesPanel
                case .addSource:
                    addSourcePanel
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 24 + topChromeInset)
            .padding(.bottom, 36)
        }
    }

    private var sourceLibraryPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Source Library")
                    .font(.headline)
                Spacer()
                Text("\(filteredPresetSources.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            PlainNewsCategoryStrip(selection: $selectedPresetCategory)
            PlainNewsSourceSearchField(text: $sourceSearch)

            LazyVStack(spacing: 8) {
                ForEach(filteredPresetSources) { source in
                    let savedSource = existingSource(for: source)
                    PlainNewsPresetRow(
                        source: source,
                        isAdded: savedSource != nil,
                        onToggle: {
                            if let savedSource {
                                onRemoveSource(savedSource)
                            } else {
                                onAddPreset(source)
                            }
                        }
                    )
                }
            }
        }
    }

    private var yourSourcesPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Your Sources")
                    .font(.headline)
                Spacer()
                Text("\(filteredSources.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            PlainNewsCategoryStrip(selection: $selectedSourceCategory)
            PlainNewsSourceSearchField(text: $sourceSearch)

            if sources.isEmpty {
                PlainNewsEmptyPanel(title: "No sources", systemName: "tray")
            } else if filteredSources.isEmpty {
                PlainNewsEmptyPanel(title: "No matches", systemName: "line.3.horizontal.decrease.circle")
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(filteredSources) { source in
                        PlainNewsSourceRow(
                            source: source,
                            onToggle: { onToggleSource(source) },
                            onRemove: { onRemoveSource(source) }
                        )
                    }
                }
            }
        }
    }

    private var addSourcePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add Source")
                .font(.headline)

            TextField("Name", text: $sourceName)
                .textFieldStyle(.roundedBorder)

            TextField("URL", text: $sourceURL)
                .textFieldStyle(.roundedBorder)

            Picker("Type", selection: $sourceKind) {
                ForEach(PlainNewsSourceKind.allCases, id: \.self) { kind in
                    Text(kind.label).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 7) {
                Text("Categories")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                PlainNewsCategoryToggleGrid(selection: $sourceCategories)
            }

            Button {
                onAddSource(sourceName, sourceURL, sourceKind, Array(sourceCategories))
                sourceName = ""
                sourceURL = ""
                sourcePanelTab = .yourSources
            } label: {
                Label("Add", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var digestPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Plain News")
                            .font(.system(size: 34, weight: .semibold, design: .serif))
                        Text(digestSubtitle)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if hasRunSurface {
                        Button {
                            onClearDigest()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.borderless)
                        .help("Clear Digest")
                    }

                    Button {
                        onRun()
                    } label: {
                        Label(isRunning ? "Running" : "Run", systemImage: isRunning ? "hourglass" : "sparkles")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning)
                }

                if hasRunSurface {
                    runSummaryPanel
                } else {
                    timeWindowPanel
                    resultLimitPanel
                    interestsPanel
                    aiStatusPanel
                }

                if let progress {
                    PlainNewsProgressView(progress: progress)
                }

                if let digest, !digest.items.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(digest.items) { item in
                            PlainNewsDigestRow(item: item) {
                                onOpenItem(item)
                            } onSaveForLater: {
                                onSaveItemForLater(item)
                            } isSavedForLater: {
                                isItemSavedForLater(item)
                            }
                        }
                    }
                } else if digest != nil {
                    PlainNewsEmptyPanel(title: "Nothing surfaced", systemName: "checkmark.circle")
                        .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
                }
            }
            .frame(maxWidth: 860, alignment: .leading)
            .padding(.horizontal, 38)
            .padding(.top, 34 + topChromeInset)
            .padding(.bottom, 56)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var timeWindowPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Time Window", systemImage: "calendar")
                .font(.headline)

            Picker("Window", selection: windowModeBinding) {
                ForEach(PlainNewsWindow.Mode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if window.mode == .rollingDays {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(window.label)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Stepper(value: rollingDaysStepperBinding, in: 1...30) {
                            Text("\(window.rollingDays)")
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                        }
                    }

                    Slider(value: rollingDaysSliderBinding, in: 1...30, step: 1)
                }
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.38), lineWidth: 1)
        }
    }

    private var resultLimitPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Results", systemImage: "number.square")
                .font(.headline)

            Toggle("Limit results", isOn: $limitsResults)
                .font(.subheadline.weight(.semibold))

            if limitsResults {
                HStack {
                    Text("Maximum")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Stepper(value: $resultLimit, in: 6...60, step: 6) {
                        Text("\(resultLimit)")
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                    }
                }
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.38), lineWidth: 1)
        }
    }

    private var interestsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Interests", systemImage: "slider.horizontal.3")
                .font(.headline)

            TextEditor(text: $interestProfile)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 76, maxHeight: 104)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.42), lineWidth: 1)
                }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.38), lineWidth: 1)
        }
    }

    private var aiStatusPanel: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: aiStatus.isAppleFoundationModelsAvailable ? "sparkles" : "function")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(aiStatus.isAppleFoundationModelsAvailable ? Color.accentColor : Color(nsColor: .secondaryLabelColor))
                .frame(width: 28, height: 28)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 3) {
                Text(aiStatus.title)
                    .font(.subheadline.weight(.semibold))
                Text(aiStatus.detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.38), lineWidth: 1)
        }
    }

    private var runSummaryPanel: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 3) {
                Text(newsWindowSummary(for: digest?.window ?? window))
                    .font(.headline)
                Text(runSummarySubtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                if digest != nil {
                    Text(selectionPolicySummary)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.38), lineWidth: 1)
        }
    }

    private var digestSubtitle: String {
        if let digest {
            return "\(digest.items.count) shown from \(digest.articleCount) article\(digest.articleCount == 1 ? "" : "s") · \(digest.modelName)"
        }

        if isRunning {
            return "Local reading pass"
        }

        return "\(enabledSourceCount) active source\(enabledSourceCount == 1 ? "" : "s") · local AI when available"
    }

    private var sourcePanelSubtitle: String? {
        switch sourcePanelTab {
        case .browse:
            return "\(PlainNewsPresetSources.sources.count) built-in sources"
        case .yourSources:
            return "\(enabledSourceCount) active source\(enabledSourceCount == 1 ? "" : "s") · \(sources.count) saved"
        case .addSource:
            return nil
        }
    }

    private var runSummarySubtitle: String {
        if let digest {
            let limitLabel = limitsResults ? "\(resultLimit) result limit" : "No result limit"
            return "\(digest.items.count) of \(digest.articleCount) shown · \(limitLabel) · \(digest.modelName)"
        }

        if isRunning {
            return "Collecting from \(enabledSourceCount) active source\(enabledSourceCount == 1 ? "" : "s")"
        }

        return "Local reading pass"
    }

    private var selectionPolicySummary: String {
        if interestProfile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "With no interests set, Plain balances recency, source variety, and available excerpts."
        }

        return "Plain prioritizes matches to your interests, then balances recency and source variety."
    }

    private func newsWindowSummary(for window: PlainNewsWindow) -> String {
        switch window.mode {
        case .rollingDays where window.rollingDays == 1:
            return "News for the last day"
        case .rollingDays:
            return "News for the last \(window.rollingDays) days"
        case .thisWeek:
            return "News for this week"
        case .yesterday:
            return "News from yesterday"
        }
    }

    private func existingSource(for source: PlainNewsSource) -> PlainNewsSource? {
        let normalized = PlainNewsArticle.normalizedURLString(source.url)
        return sources.first { existing in
            PlainNewsArticle.normalizedURLString(existing.url) == normalized
        }
    }
}

struct PlainNewsSourceRow: View {
    var source: PlainNewsSource
    var onToggle: () -> Void
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Button {
                onToggle()
            } label: {
                Image(systemName: source.isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(source.isEnabled ? Color.accentColor : Color(nsColor: .secondaryLabelColor))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(source.isEnabled ? "Disable" : "Enable")

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(source.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(source.kind.label)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                Text(source.url.host(percentEncoded: false) ?? source.url.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                PlainNewsCategoryChips(categories: source.categories, limit: 3)
            }

            Spacer(minLength: 6)

            Button {
                onRemove()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .help("Remove")
        }
        .padding(.leading, 8)
        .padding(.trailing, 6)
        .padding(.vertical, 9)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.36), lineWidth: 1)
        }
    }
}

struct PlainNewsCategoryStrip: View {
    @Binding var selection: PlainNewsCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                PlainNewsCategoryButton(
                    title: "All",
                    systemName: "square.grid.2x2",
                    isSelected: selection == nil
                ) {
                    selection = nil
                }

                ForEach(PlainNewsCategory.allCases, id: \.self) { category in
                    PlainNewsCategoryButton(
                        title: category.label,
                        systemName: category.systemImage,
                        isSelected: selection == category
                    ) {
                        selection = category
                    }
                }
            }
            .padding(.vertical, 1)
        }
    }
}

struct PlainNewsCategoryToggleGrid: View {
    @Binding var selection: Set<PlainNewsCategory>

    private let columns = [
        GridItem(.adaptive(minimum: 132), spacing: 7, alignment: .leading)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 7) {
            ForEach(PlainNewsCategory.allCases, id: \.self) { category in
                toggle(for: category)
            }
        }
    }

    private func toggle(for category: PlainNewsCategory) -> some View {
        PlainNewsCategoryButton(
            title: category.label,
            systemName: category.systemImage,
            isSelected: selection.contains(category)
        ) {
            if selection.contains(category) {
                selection.remove(category)
            } else {
                selection.insert(category)
            }
        }
    }
}

struct PlainNewsSourceSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField("Search sources", text: $text)
                .textFieldStyle(.plain)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.9))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        }
    }
}

struct PlainNewsCategoryButton: View {
    var title: String
    var systemName: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemName)
                    .font(.system(size: 10.5, weight: .semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .lineLimit(1)
            .foregroundStyle(isSelected ? Color.accentColor : Color(nsColor: .secondaryLabelColor))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                isSelected ? Color.accentColor.opacity(0.14) : Color(nsColor: .textBackgroundColor).opacity(0.8),
                in: RoundedRectangle(cornerRadius: 7)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(
                        isSelected ? Color.accentColor.opacity(0.24) : Color(nsColor: .separatorColor).opacity(0.34),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

private extension PlainNewsSource {
    func matchesSearch(_ value: String) -> Bool {
        let search = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !search.isEmpty else {
            return true
        }

        return name.localizedCaseInsensitiveContains(search)
            || url.absoluteString.localizedCaseInsensitiveContains(search)
            || categories.contains { $0.label.localizedCaseInsensitiveContains(search) }
    }
}

struct PlainNewsCategoryChips: View {
    var categories: [PlainNewsCategory]
    var limit = 4

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(categories.prefix(limit)), id: \.self) { category in
                HStack(spacing: 4) {
                    Image(systemName: category.systemImage)
                    Text(category.label)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.9), in: RoundedRectangle(cornerRadius: 5))
            }

            if categories.count > limit {
                Text("+\(categories.count - limit)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .lineLimit(1)
    }
}

struct PlainNewsPresetRow: View {
    var source: PlainNewsSource
    var isAdded: Bool
    var onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: source.kind == .rss ? "dot.radiowaves.left.and.right" : "globe")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(source.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(source.kind.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                PlainNewsCategoryChips(categories: source.categories, limit: 2)
            }

            Spacer()

            Button {
                onToggle()
            } label: {
                Image(systemName: isAdded ? "checkmark" : "plus")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 25, height: 25)
            }
            .buttonStyle(.plain)
            .help(isAdded ? "Remove" : "Add")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct PlainNewsDigestRow: View {
    var item: PlainNewsDigestItem
    var onOpen: () -> Void
    var onSaveForLater: () -> Void
    var isSavedForLater: () -> Bool

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(item.article.sourceName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let publishedAt = item.article.publishedAt {
                        Text(publishedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

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

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Button {
                    onSaveForLater()
                } label: {
                    Image(systemName: isSavedForLater() ? "checkmark" : "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isSavedForLater() ? Color.green : Color(nsColor: .secondaryLabelColor))
                        .frame(width: 28, height: 28)
                        .background(Color(nsColor: .textBackgroundColor).opacity(0.86), in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .disabled(isSavedForLater())
                .help(isSavedForLater() ? "Saved to Later" : "Save to Later")

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

struct PlainNewsProgressView: View {
    var progress: PlainNewsProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(progress.message, systemImage: progress.stage == .collecting ? "arrow.down.circle" : "sparkles")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(progressText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progressValue)
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.38), lineWidth: 1)
        }
    }

    private var progressText: String {
        guard progress.total > 0 else {
            return ""
        }
        return "\(progress.completed)/\(progress.total)"
    }

    private var progressValue: Double {
        guard progress.total > 0 else {
            return 0
        }
        return Double(progress.completed) / Double(progress.total)
    }
}

struct PlainNewsEmptyPanel: View {
    var title: String
    var systemName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
        }
        .foregroundStyle(.secondary)
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        }
    }
}
