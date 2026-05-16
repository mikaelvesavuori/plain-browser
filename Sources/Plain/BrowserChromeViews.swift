import AppKit
import PlainCore
import SwiftUI

struct FloatingStatusToast: View {
    var message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
            .accessibilityLabel(message)
    }
}

struct UpdateNoticeBanner: View {
    var update: AppUpdate
    var onOpen: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tint)

            Text("Plain \(update.latestVersion) is available")
                .font(.caption.weight(.semibold))
                .lineLimit(1)

            Button {
                onOpen()
            } label: {
                Text("Open")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .contentShape(RoundedRectangle(cornerRadius: 6))

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("Dismiss")
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Plain \(update.latestVersion) is available")
    }
}

struct ToolbarIconButton: View {
    var systemName: String
    var help: String
    var isEnabled = true
    var isActive = false
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(backgroundColor)
                Image(systemName: systemName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(foregroundColor)
            }
            .frame(width: 32, height: 32)
            .contentShape(RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(borderColor, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        .help(help)
        .frame(width: 32, height: 32)
        .onHover { isHovering = $0 }
    }

    private var foregroundColor: Color {
        if isActive {
            return .accentColor
        }
        return Color(nsColor: .secondaryLabelColor)
    }

    private var backgroundColor: Color {
        if isActive {
            return Color.accentColor.opacity(0.16)
        }
        if isHovering && isEnabled {
            return Color(nsColor: .controlBackgroundColor).opacity(0.9)
        }
        return Color.clear
    }

    private var borderColor: Color {
        if isActive {
            return Color.accentColor.opacity(0.22)
        }
        if isHovering && isEnabled {
            return Color(nsColor: .separatorColor).opacity(0.36)
        }
        return Color.clear
    }
}

struct MoreMenuPanel: View {
    var appearance: AppAppearance
    var showsImages: Bool
    var canCopyDocument: Bool
    var canExportLater: Bool
    var canShowHistory: Bool
    var canReportPageIssue: Bool
    var onAppearance: (AppAppearance) -> Void
    var onToggleImages: () -> Void
    var onCopyCleanText: () -> Void
    var onCopyMarkdown: () -> Void
    var onExportLater: () -> Void
    var onClearLater: () -> Void
    var onShowHistory: () -> Void
    var onReportPageIssue: () -> Void
    var onClearHistory: () -> Void
    var onClearImageCache: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            MoreMenuRow(
                title: "System Appearance",
                systemName: "circle.lefthalf.filled",
                isSelected: appearance == .system
            ) {
                onAppearance(.system)
            }

            MoreMenuRow(
                title: "Light Mode",
                systemName: "sun.max",
                isSelected: appearance == .light
            ) {
                onAppearance(.light)
            }

            MoreMenuRow(
                title: "Dark Mode",
                systemName: "moon",
                isSelected: appearance == .dark
            ) {
                onAppearance(.dark)
            }

            MoreMenuSeparator()

            MoreMenuRow(
                title: "Load with Images",
                systemName: showsImages ? "photo.fill" : "photo",
                isSelected: showsImages
            ) {
                onToggleImages()
            }

            MoreMenuRow(
                title: "Export Later",
                systemName: "square.and.arrow.up",
                isEnabled: canExportLater
            ) {
                onExportLater()
            }

            MoreMenuRow(
                title: "Clear Later",
                systemName: "bookmark.slash",
                isEnabled: canExportLater
            ) {
                onClearLater()
            }

            MoreMenuSeparator()

            MoreMenuRow(
                title: "Copy Clean Text",
                systemName: "doc.on.doc",
                isEnabled: canCopyDocument
            ) {
                onCopyCleanText()
            }

            MoreMenuRow(
                title: "Copy Markdown",
                systemName: "text.badge.star",
                isEnabled: canCopyDocument
            ) {
                onCopyMarkdown()
            }

            MoreMenuSeparator()

            MoreMenuRow(
                title: "Report Page Issue",
                systemName: "envelope.badge",
                isEnabled: canReportPageIssue
            ) {
                onReportPageIssue()
            }

            MoreMenuSeparator()

            MoreMenuRow(
                title: "Show History",
                systemName: "clock",
                isEnabled: canShowHistory
            ) {
                onShowHistory()
            }

            MoreMenuRow(title: "Clear History", systemName: "clock.arrow.circlepath") {
                onClearHistory()
            }

            MoreMenuRow(title: "Clear Image Cache", systemName: "photo.badge.checkmark") {
                onClearImageCache()
            }
        }
        .padding(7)
        .frame(width: 220)
    }
}

struct MoreMenuRow: View {
    var title: String
    var systemName: String
    var isSelected = false
    var isEnabled = true
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: systemName)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 17)

                Text(title)
                    .font(.system(size: 12.5, weight: .medium))

                Spacer(minLength: 8)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(.tint)
                }
            }
            .foregroundStyle(.primary)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.42)
        .background(
            isHovering && isEnabled ? Color.accentColor.opacity(0.12) : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
        .onHover { isHovering = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct MoreMenuSeparator: View {
    var body: some View {
        Divider()
            .padding(.vertical, 3)
    }
}

enum AppAppearance: String {
    case system
    case light
    case dark

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

enum NavigationSwipeDirection: Equatable {
    case back
    case forward

    var systemName: String {
        switch self {
        case .back:
            return "chevron.left"
        case .forward:
            return "chevron.right"
        }
    }

    var label: String {
        switch self {
        case .back:
            return "Back"
        case .forward:
            return "Forward"
        }
    }
}

struct NavigationSwipeCue: View {
    var direction: NavigationSwipeDirection

    var body: some View {
        Label(direction.label, systemImage: direction.systemName)
            .font(.system(size: 17, weight: .semibold))
            .labelStyle(.iconOnly)
            .foregroundStyle(.white)
            .frame(width: 68, height: 68)
            .background(Color.black.opacity(0.68), in: Circle())
            .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
            .accessibilityLabel(direction.label)
    }
}

struct EscapeKeyMonitor: NSViewRepresentable {
    var isEnabled: Bool
    var onEscape: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.install(for: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.view = nsView
        context.coordinator.isEnabled = isEnabled
        context.coordinator.onEscape = onEscape
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator {
        weak var view: NSView?
        var isEnabled = false
        var onEscape: () -> Void = {}
        private var monitor: Any?

        func install(for view: NSView) {
            self.view = view
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else {
                    return event
                }

                guard self.isEnabled,
                      event.keyCode == 53 else {
                    return event
                }

                self.onEscape()
                return nil
            }
        }

        func uninstall() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }
    }
}

struct NavigationSwipeMonitor: NSViewRepresentable {
    var isEnabled: Bool
    var canGoBack: Bool
    var canGoForward: Bool
    var onBack: () -> Void
    var onForward: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.install(for: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.view = nsView
        context.coordinator.isEnabled = isEnabled
        context.coordinator.canGoBack = canGoBack
        context.coordinator.canGoForward = canGoForward
        context.coordinator.onBack = onBack
        context.coordinator.onForward = onForward
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator {
        weak var view: NSView?
        var isEnabled = true
        var canGoBack = false
        var canGoForward = false
        var onBack: () -> Void = {}
        var onForward: () -> Void = {}

        private var monitor: Any?
        private var accumulatedX: CGFloat = 0
        private var accumulatedY: CGFloat = 0
        private var didTrigger = false
        private var lastTriggerTime: TimeInterval = 0

        func install(for view: NSView) {
            self.view = view
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .swipe]) { [weak self] event in
                guard let self else {
                    return event
                }

                guard self.isEnabled else {
                    return event
                }

                switch event.type {
                case .swipe:
                    self.handleSwipeEvent(event)
                case .scrollWheel:
                    self.handleScrollWheelEvent(event)
                default:
                    break
                }

                return event
            }
        }

        func uninstall() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }

        private func handleSwipeEvent(_ event: NSEvent) {
            if event.deltaX > 0 {
                triggerBack()
            } else if event.deltaX < 0 {
                triggerForward()
            }
        }

        private func handleScrollWheelEvent(_ event: NSEvent) {
            if event.phase == .began {
                resetGesture()
            }

            accumulatedX += event.scrollingDeltaX
            accumulatedY += event.scrollingDeltaY

            let mostlyHorizontal = abs(accumulatedX) > max(70, abs(accumulatedY) * 1.7)
            if !didTrigger, mostlyHorizontal {
                if accumulatedX > 0 {
                    triggerBack()
                } else {
                    triggerForward()
                }
                didTrigger = true
            }

            if event.phase == .ended ||
                event.phase == .cancelled ||
                event.momentumPhase == .ended ||
                event.momentumPhase == .cancelled {
                resetGesture()
            }
        }

        private func triggerBack() {
            guard canGoBack, canTriggerNow() else {
                return
            }
            markTriggered()
            onBack()
        }

        private func triggerForward() {
            guard canGoForward, canTriggerNow() else {
                return
            }
            markTriggered()
            onForward()
        }

        private func canTriggerNow() -> Bool {
            ProcessInfo.processInfo.systemUptime - lastTriggerTime > 0.65
        }

        private func markTriggered() {
            lastTriggerTime = ProcessInfo.processInfo.systemUptime
        }

        private func resetGesture() {
            accumulatedX = 0
            accumulatedY = 0
            didTrigger = false
        }
    }
}
