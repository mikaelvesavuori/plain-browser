import AppKit
import PlainCore
import SwiftUI

struct BrowserView: View {
    @StateObject private var viewModel = BrowserViewModel()
    @AppStorage("Plain.Appearance") private var appearanceRawValue = AppAppearance.system.rawValue
    @AppStorage("Plain.ReaderFontFamily") private var readerFontFamilyRawValue = ReaderFontFamily.serif.rawValue
    @AppStorage("Plain.ReaderTextSize") private var readerTextSizeRawValue = ReaderTextSize.medium.rawValue
    @AppStorage("Plain.HasSeenWelcome") private var hasSeenWelcome = false
    @Environment(\.colorScheme) private var systemColorScheme
    @FocusState private var isAddressFocused: Bool
    @FocusState private var isFindFocused: Bool
    @State private var swipeFeedback: NavigationSwipeDirection?
    @State private var isMoreMenuPresented = false
    @State private var isLaterPopoverPresented = false
    @State private var isToolbarRevealZoneHovered = false
    @State private var isToolbarHovered = false
    @State private var isToolbarVisibleByPointer = false
    @State private var toolbarHideTask: Task<Void, Never>?
    @State private var isFindPresented = false
    @State private var findQuery = ""
    @State private var selectedFindIndex = 0

    private var appearance: AppAppearance {
        AppAppearance(rawValue: appearanceRawValue) ?? .system
    }

    private var readerFontFamily: ReaderFontFamily {
        ReaderFontFamily(rawValue: readerFontFamilyRawValue) ?? .serif
    }

    private var readerTextSize: ReaderTextSize {
        ReaderTextSize(rawValue: readerTextSizeRawValue) ?? .medium
    }

    private var readerSettings: ReaderDisplaySettings {
        ReaderDisplaySettings(fontFamily: readerFontFamily, textSize: readerTextSize)
    }

    private var effectiveColorScheme: ColorScheme {
        appearance.preferredColorScheme ?? systemColorScheme
    }

    private var isToolbarVisible: Bool {
        isToolbarVisibleByPointer || isAddressFocused || isMoreMenuPresented || isLaterPopoverPresented
    }

    private var toolbarAnimation: Animation {
        .spring(response: 0.22, dampingFraction: 0.88)
    }

    private let toolbarContentInset: CGFloat = 58

    private var findIndex: DocumentFindIndex {
        DocumentFindIndex(document: viewModel.currentDocument, query: findQuery)
    }

    private var selectedFindMatch: DocumentFindMatch? {
        let matches = findIndex.matches
        guard !matches.isEmpty else {
            return nil
        }

        return matches[min(selectedFindIndex, matches.count - 1)]
    }

    private var commandActions: PlainCommandActions {
        PlainCommandActions(
            canGoBack: viewModel.canGoBack,
            canGoForward: viewModel.canGoForward,
            canReload: viewModel.currentURL != nil,
            canFind: viewModel.currentDocument != nil,
            canOpenInDefaultBrowser: viewModel.currentURL != nil,
            canCopyDocument: viewModel.currentDocument != nil,
            canSaveForLater: viewModel.currentURL != nil,
            canShowLater: true,
            canShowHistory: !viewModel.recentPages.isEmpty,
            canExportLater: !viewModel.laterItems.isEmpty,
            canDecreaseTextSize: readerTextSize.canDecrease,
            canIncreaseTextSize: readerTextSize.canIncrease,
            focusAddress: focusAddressBar,
            reload: viewModel.reloadCurrent,
            goBack: navigateBackWithFlair,
            goForward: navigateForwardWithFlair,
            presentFind: presentFind,
            findNext: findNext,
            findPrevious: findPrevious,
            toggleImages: toggleImages,
            toggleAppearance: toggleAppearance,
            toggleReaderFontFamily: toggleReaderFontFamily,
            decreaseTextSize: decreaseReaderTextSize,
            increaseTextSize: increaseReaderTextSize,
            toggleFullScreen: toggleFullScreen,
            openInDefaultBrowser: viewModel.openCurrentInDefaultBrowser,
            saveForLater: viewModel.toggleCurrentLater,
            showLater: showLater,
            showHistory: showHistory,
            exportLater: viewModel.exportLater,
            copyCleanText: viewModel.copyCleanText,
            copyMarkdown: viewModel.copyMarkdown
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            content
                .contentShape(Rectangle())
                .simultaneousGesture(mouseSwipeGesture)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            toolbarRevealZone
                .zIndex(1)

            toolbar
                .offset(y: isToolbarVisible ? 0 : -76)
                .allowsHitTesting(isToolbarVisible)
                .onHover { isHovered in
                    setToolbarHovered(isHovered)
                }
                .zIndex(2)

            if let swipeFeedback {
                NavigationSwipeCue(direction: swipeFeedback)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                    .allowsHitTesting(false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .zIndex(3)
            }
        }
        .frame(minWidth: 860, minHeight: 620)
        .preferredColorScheme(appearance.preferredColorScheme)
        .focusedSceneValue(\.plainCommandActions, commandActions)
        .overlay(alignment: .topTrailing) {
            VStack(alignment: .trailing, spacing: 8) {
                if isFindPresented {
                    findBar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if let statusMessage = viewModel.statusMessage {
                    FloatingStatusToast(message: statusMessage)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if let updateNotice = viewModel.updateNotice {
                    UpdateNoticeBanner(
                        update: updateNotice,
                        onOpen: viewModel.openLatestRelease,
                        onDismiss: viewModel.dismissUpdateNotice
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.top, toolbarContentInset)
            .padding(.trailing, 16)
        }
        .animation(.easeOut(duration: 0.16), value: viewModel.statusMessage)
        .animation(.easeOut(duration: 0.16), value: viewModel.updateNotice)
        .animation(.easeOut(duration: 0.16), value: isFindPresented)
        .animation(toolbarAnimation, value: isToolbarVisible)
        .background(
            EscapeKeyMonitor(isEnabled: isAddressFocused || isFindFocused) {
                if isFindFocused {
                    closeFind()
                } else {
                    dismissAddressFocus()
                }
            }
        )
        .background(
            NavigationSwipeMonitor(
                isEnabled: !isAddressFocused,
                canGoBack: viewModel.canGoBack,
                canGoForward: viewModel.canGoForward,
                onBack: {
                    navigateBackWithFlair()
                },
                onForward: {
                    navigateForwardWithFlair()
                }
            )
        )
        .onAppear {
            viewModel.loadStartupURLIfAvailable()
            viewModel.checkForUpdatesOnStartup()
        }
        .onOpenURL { url in
            viewModel.openHandoffURL(url)
        }
        .onChange(of: findQuery) { _, _ in
            selectedFindIndex = 0
        }
        .onChange(of: viewModel.currentURL) { _, _ in
            selectedFindIndex = 0
        }
        .onDisappear {
            toolbarHideTask?.cancel()
        }
    }

    private var toolbarRevealZone: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 24)
            .contentShape(Rectangle())
            .onHover { isHovered in
                setToolbarRevealZoneHovered(isHovered)
            }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                ToolbarIconButton(
                    systemName: "chevron.left",
                    help: "Back",
                    isEnabled: viewModel.canGoBack
                ) {
                    navigateBackWithFlair()
                }

                ToolbarIconButton(
                    systemName: "chevron.right",
                    help: "Forward",
                    isEnabled: viewModel.canGoForward
                ) {
                    navigateForwardWithFlair()
                }
            }
            .padding(3)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
            }

            addressBar

            ToolbarIconButton(
                systemName: viewModel.currentIsInLater ? "bookmark.fill" : "bookmark",
                help: viewModel.currentIsInLater ? "Remove from Later (Cmd-D)" : "Save for Later (Cmd-D)",
                isEnabled: viewModel.currentURL != nil,
                isActive: viewModel.currentIsInLater
            ) {
                viewModel.toggleCurrentLater()
            }

            ToolbarIconButton(
                systemName: "list.bullet",
                help: "Show Later (Shift-Cmd-D)",
                isActive: isLaterPopoverPresented
            ) {
                showLater()
            }
            .popover(isPresented: $isLaterPopoverPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                LaterPopoverPanel(
                    items: viewModel.laterItems,
                    onOpen: { item in
                        isLaterPopoverPresented = false
                        viewModel.loadLater(item)
                    },
                    onRemove: { item in
                        if viewModel.laterItems.count <= 1 {
                            isLaterPopoverPresented = false
                            DispatchQueue.main.async {
                                viewModel.removeFromLater(item)
                            }
                        } else {
                            viewModel.removeFromLater(item)
                        }
                    },
                    onExport: {
                        isLaterPopoverPresented = false
                        viewModel.exportLater()
                    },
                    onClear: {
                        isLaterPopoverPresented = false
                        DispatchQueue.main.async {
                            viewModel.clearLater()
                        }
                    }
                )
                .preferredColorScheme(appearance.preferredColorScheme)
            }

            Divider()
                .frame(height: 22)

            ToolbarIconButton(
                systemName: "globe",
                help: "Open in Default Browser",
                isEnabled: viewModel.currentURL != nil
            ) {
                viewModel.openCurrentInDefaultBrowser()
            }

            ToolbarIconButton(
                systemName: appearanceIconName,
                help: appearanceHelpText
            ) {
                toggleAppearance()
            }

            ToolbarIconButton(
                systemName: readerFontFamily.toolbarIconName,
                help: readerFontFamily.toggleHelpText
            ) {
                toggleReaderFontFamily()
            }

            ToolbarIconButton(
                systemName: "textformat.size",
                help: "Cycle Text Size"
            ) {
                cycleReaderTextSize()
            }

            ToolbarIconButton(
                systemName: "arrow.up.left.and.arrow.down.right",
                help: "Toggle Full Screen"
            ) {
                toggleFullScreen()
            }

            ToolbarIconButton(
                systemName: "ellipsis",
                help: "More",
                isActive: isMoreMenuPresented
            ) {
                isMoreMenuPresented.toggle()
            }
            .popover(isPresented: $isMoreMenuPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                MoreMenuPanel(
                    appearance: appearance,
                    showsImages: viewModel.showsImages,
                    canCopyDocument: viewModel.currentDocument != nil,
                    canExportLater: !viewModel.laterItems.isEmpty,
                    canShowHistory: !viewModel.recentPages.isEmpty,
                    canReportPageIssue: viewModel.currentURL != nil,
                    onAppearance: { nextAppearance in
                        appearanceRawValue = nextAppearance.rawValue
                        isMoreMenuPresented = false
                    },
                    onToggleImages: {
                        toggleImages()
                        isMoreMenuPresented = false
                    },
                    onCopyCleanText: {
                        isMoreMenuPresented = false
                        viewModel.copyCleanText()
                    },
                    onCopyMarkdown: {
                        isMoreMenuPresented = false
                        viewModel.copyMarkdown()
                    },
                    onExportLater: {
                        isMoreMenuPresented = false
                        viewModel.exportLater()
                    },
                    onClearLater: {
                        isMoreMenuPresented = false
                        viewModel.clearLater()
                    },
                    onShowHistory: {
                        isMoreMenuPresented = false
                        showHistory()
                    },
                    onReportPageIssue: {
                        isMoreMenuPresented = false
                        viewModel.reportCurrentPageIssue()
                    },
                    onClearHistory: {
                        isMoreMenuPresented = false
                        viewModel.clearHistory()
                    },
                    onClearImageCache: {
                        isMoreMenuPresented = false
                        viewModel.clearCache()
                    }
                )
                .preferredColorScheme(appearance.preferredColorScheme)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.5))
                .frame(height: 1)
        }
        .shadow(color: .black.opacity(isToolbarVisible ? 0.08 : 0), radius: 18, y: 6)
    }

    private var findBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField("Find in page", text: $findQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .focused($isFindFocused)
                .onSubmit {
                    findNext()
                }
                .onExitCommand {
                    closeFind()
                }

            Text(findStatusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(findIndex.matches.isEmpty && !findIndex.query.isEmpty ? .red : .secondary)
                .lineLimit(1)
                .frame(minWidth: 58, alignment: .trailing)

            ToolbarIconButton(
                systemName: "chevron.up",
                help: "Find Previous",
                isEnabled: !findIndex.matches.isEmpty
            ) {
                findPrevious()
            }

            ToolbarIconButton(
                systemName: "chevron.down",
                help: "Find Next",
                isEnabled: !findIndex.matches.isEmpty
            ) {
                findNext()
            }

            ToolbarIconButton(
                systemName: "xmark",
                help: "Close Find"
            ) {
                closeFind()
            }
        }
        .padding(.leading, 11)
        .padding(.trailing, 7)
        .padding(.vertical, 7)
        .frame(width: 390)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 14, y: 5)
    }

    private var findStatusText: String {
        guard !findIndex.query.isEmpty else {
            return ""
        }

        let matches = findIndex.matches
        guard !matches.isEmpty else {
            return "No results"
        }

        return "\(min(selectedFindIndex, matches.count - 1) + 1) of \(matches.count)"
    }

    private var addressBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "globe")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Search or enter a URL", text: $viewModel.address)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium))
                .focused($isAddressFocused)
                .onSubmit {
                    viewModel.loadAddress()
                }
                .onExitCommand {
                    dismissAddressFocus()
                }

            if case .loading = viewModel.state {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 18, height: 18)
            }

            Button {
                viewModel.loadAddress()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.12))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                }
                .frame(width: 28, height: 28)
                .contentShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Load")
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            StartView(
                recentPages: viewModel.recentPages,
                laterItems: viewModel.laterItems,
                showsWelcome: !hasSeenWelcome,
                topChromeInset: toolbarContentInset,
                onOpen: viewModel.loadRecent,
                onOpenLater: viewModel.loadLater,
                onRemoveLater: viewModel.removeFromLater,
                onExportLater: viewModel.exportLater,
                onClearLater: viewModel.clearLater,
                onClear: viewModel.clearHistory,
                onDismissWelcome: {
                    hasSeenWelcome = true
                }
            )
        case .loading(let url):
            LoadingView(url: url)
        case .loaded(let document):
            DocumentView(
                document: document,
                showsImages: viewModel.showsImages,
                readerSettings: readerSettings,
                selectedFindTarget: isFindPresented ? selectedFindMatch?.target : nil,
                topChromeInset: toolbarContentInset,
                onOpenLink: viewModel.openLink
            )
        case .failed(let failure):
            FailureView(
                failure: failure,
                onOpenInDefaultBrowser: viewModel.openCurrentInDefaultBrowser,
                onReportIssue: viewModel.reportCurrentPageIssue
            )
        }
    }

    private var mouseSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 70)
            .onEnded { value in
                guard !isAddressFocused else {
                    return
                }

                let width = value.translation.width
                let height = value.translation.height
                guard abs(width) > 90, abs(width) > abs(height) * 1.45 else {
                    return
                }

                if width > 0 {
                    navigateBackWithFlair()
                } else {
                    navigateForwardWithFlair()
                }
            }
    }

    private var appearanceIconName: String {
        effectiveColorScheme == .dark ? "sun.max" : "moon"
    }

    private var appearanceHelpText: String {
        effectiveColorScheme == .dark ? "Switch to Light Mode" : "Switch to Dark Mode"
    }

    private func toggleAppearance() {
        appearanceRawValue = effectiveColorScheme == .dark
            ? AppAppearance.light.rawValue
            : AppAppearance.dark.rawValue
    }

    private func toggleImages() {
        viewModel.showsImages.toggle()
    }

    private func toggleReaderFontFamily() {
        readerFontFamilyRawValue = readerFontFamily.toggled.rawValue
    }

    private func cycleReaderTextSize() {
        readerTextSizeRawValue = readerTextSize.cycled.rawValue
    }

    private func decreaseReaderTextSize() {
        readerTextSizeRawValue = readerTextSize.smaller.rawValue
    }

    private func increaseReaderTextSize() {
        readerTextSizeRawValue = readerTextSize.larger.rawValue
    }

    private func toggleFullScreen() {
        (NSApp.keyWindow ?? NSApp.windows.first)?.toggleFullScreen(nil)
    }

    private func showLater() {
        isMoreMenuPresented = false
        isAddressFocused = false
        isFindFocused = false
        closeFind()
        withAnimation(toolbarAnimation) {
            isToolbarVisibleByPointer = true
        }

        DispatchQueue.main.async {
            isLaterPopoverPresented = true
        }
    }

    private func showHistory() {
        isMoreMenuPresented = false
        isLaterPopoverPresented = false
        isAddressFocused = false
        isFindFocused = false
        closeFind()
        viewModel.showHistory()
        withAnimation(toolbarAnimation) {
            isToolbarVisibleByPointer = true
        }
    }

    private func focusAddressBar() {
        closeFind(shouldClearFocus: true)
        withAnimation(toolbarAnimation) {
            isToolbarVisibleByPointer = true
        }

        DispatchQueue.main.async {
            isAddressFocused = true
        }
    }

    private func presentFind() {
        guard viewModel.currentDocument != nil else {
            return
        }

        isAddressFocused = false
        isFindPresented = true

        DispatchQueue.main.async {
            isFindFocused = true
        }
    }

    private func closeFind(shouldClearFocus: Bool = true) {
        isFindPresented = false
        if shouldClearFocus {
            isFindFocused = false
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
    }

    private func findNext() {
        guard viewModel.currentDocument != nil else {
            return
        }

        if !isFindPresented {
            presentFind()
        }

        let matches = findIndex.matches
        guard !matches.isEmpty else {
            return
        }

        selectedFindIndex = (min(selectedFindIndex, matches.count - 1) + 1) % matches.count
    }

    private func findPrevious() {
        guard viewModel.currentDocument != nil else {
            return
        }

        if !isFindPresented {
            presentFind()
        }

        let matches = findIndex.matches
        guard !matches.isEmpty else {
            return
        }

        let currentIndex = min(selectedFindIndex, matches.count - 1)
        selectedFindIndex = currentIndex == 0 ? matches.count - 1 : currentIndex - 1
    }

    private func setToolbarRevealZoneHovered(_ isHovered: Bool) {
        isToolbarRevealZoneHovered = isHovered
        updateToolbarPointerVisibility()
    }

    private func setToolbarHovered(_ isHovered: Bool) {
        isToolbarHovered = isHovered
        updateToolbarPointerVisibility()
    }

    private func updateToolbarPointerVisibility() {
        toolbarHideTask?.cancel()

        if isToolbarRevealZoneHovered || isToolbarHovered {
            withAnimation(toolbarAnimation) {
                isToolbarVisibleByPointer = true
            }
            return
        }

        toolbarHideTask = Task {
            try? await Task.sleep(for: .milliseconds(220))

            await MainActor.run {
                if !isToolbarRevealZoneHovered && !isToolbarHovered {
                    withAnimation(toolbarAnimation) {
                        isToolbarVisibleByPointer = false
                    }
                }
            }
        }
    }

    private func dismissAddressFocus() {
        isAddressFocused = false
        NSApp.keyWindow?.makeFirstResponder(nil)
    }

    private func navigateBackWithFlair() {
        guard viewModel.canGoBack else {
            return
        }
        viewModel.goBack()
        flashSwipeFeedback(.back)
    }

    private func navigateForwardWithFlair() {
        guard viewModel.canGoForward else {
            return
        }
        viewModel.goForward()
        flashSwipeFeedback(.forward)
    }

    private func flashSwipeFeedback(_ direction: NavigationSwipeDirection) {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
            swipeFeedback = direction
        }

        Task {
            try? await Task.sleep(for: .milliseconds(620))
            await MainActor.run {
                if swipeFeedback == direction {
                    withAnimation(.easeOut(duration: 0.16)) {
                        swipeFeedback = nil
                    }
                }
            }
        }
    }
}
