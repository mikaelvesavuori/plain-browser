import SwiftUI

struct PlainCommandActions {
    var canGoBack: Bool
    var canGoForward: Bool
    var canReload: Bool
    var canFind: Bool
    var canOpenInDefaultBrowser: Bool
    var canCopyDocument: Bool
    var canSaveForLater: Bool
    var canShowLater: Bool
    var canShowHistory: Bool
    var canShowQuotes: Bool
    var canExportLater: Bool
    var canDecreaseTextSize: Bool
    var canIncreaseTextSize: Bool
    var focusAddress: () -> Void
    var reload: () -> Void
    var goBack: () -> Void
    var goForward: () -> Void
    var presentFind: () -> Void
    var findNext: () -> Void
    var findPrevious: () -> Void
    var toggleImages: () -> Void
    var toggleAppearance: () -> Void
    var toggleReaderFontFamily: () -> Void
    var decreaseTextSize: () -> Void
    var increaseTextSize: () -> Void
    var toggleFullScreen: () -> Void
    var openInDefaultBrowser: () -> Void
    var saveForLater: () -> Void
    var showStart: () -> Void
    var showLater: () -> Void
    var showHistory: () -> Void
    var showNews: () -> Void
    var showQuotes: () -> Void
    var exportLater: () -> Void
    var importLater: () -> Void
    var copyCleanText: () -> Void
    var copyMarkdown: () -> Void
}

private struct PlainCommandActionsKey: FocusedValueKey {
    typealias Value = PlainCommandActions
}

extension FocusedValues {
    var plainCommandActions: PlainCommandActions? {
        get { self[PlainCommandActionsKey.self] }
        set { self[PlainCommandActionsKey.self] = newValue }
    }
}

struct PlainCommands: Commands {
    @FocusedValue(\.plainCommandActions) private var actions

    var body: some Commands {
        CommandMenu("Navigate") {
            Button("Open Location") {
                actions?.focusAddress()
            }
            .keyboardShortcut("l", modifiers: [.command])
            .disabled(actions == nil)

            Button("Reload") {
                actions?.reload()
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(actions?.canReload != true)

            Divider()

            Button("Back") {
                actions?.goBack()
            }
            .keyboardShortcut("[", modifiers: [.command])
            .disabled(actions?.canGoBack != true)

            Button("Forward") {
                actions?.goForward()
            }
            .keyboardShortcut("]", modifiers: [.command])
            .disabled(actions?.canGoForward != true)

            Divider()

            Button("Open in Default Browser") {
                actions?.openInDefaultBrowser()
            }
            .keyboardShortcut("o", modifiers: [.command, .option])
            .disabled(actions?.canOpenInDefaultBrowser != true)

            Divider()

            Button("Show Start Page") {
                actions?.showStart()
            }
            .disabled(actions == nil)

            Button("Save/Remove from Later") {
                actions?.saveForLater()
            }
            .keyboardShortcut("d", modifiers: [.command])
            .disabled(actions?.canSaveForLater != true)

            Button("Show Later List") {
                actions?.showLater()
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
            .disabled(actions?.canShowLater != true)

            Button("Show History") {
                actions?.showHistory()
            }
            .keyboardShortcut("y", modifiers: [.command])
            .disabled(actions?.canShowHistory != true)

            Button("Show Quotes") {
                actions?.showQuotes()
            }
            .keyboardShortcut("q", modifiers: [.command, .option])
            .disabled(actions?.canShowQuotes != true)

            Button("Show Plain News") {
                actions?.showNews()
            }
            .disabled(actions == nil)

            Button("Export Later") {
                actions?.exportLater()
            }
            .disabled(actions?.canExportLater != true)

            Button("Import Later") {
                actions?.importLater()
            }
            .disabled(actions == nil)
        }

        CommandMenu("Reader") {
            Button("Find") {
                actions?.presentFind()
            }
            .keyboardShortcut("f", modifiers: [.command])
            .disabled(actions?.canFind != true)

            Button("Find Next") {
                actions?.findNext()
            }
            .keyboardShortcut("g", modifiers: [.command])
            .disabled(actions?.canFind != true)

            Button("Find Previous") {
                actions?.findPrevious()
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
            .disabled(actions?.canFind != true)

            Divider()

            Button("Smaller Text") {
                actions?.decreaseTextSize()
            }
            .keyboardShortcut("-", modifiers: [.command])
            .disabled(actions?.canDecreaseTextSize != true)

            Button("Larger Text") {
                actions?.increaseTextSize()
            }
            .keyboardShortcut("+", modifiers: [.command])
            .disabled(actions?.canIncreaseTextSize != true)

            Button("Toggle Serif/Sans Font") {
                actions?.toggleReaderFontFamily()
            }
            .keyboardShortcut("t", modifiers: [.command, .option])
            .disabled(actions == nil)

            Divider()

            Button("Toggle Images") {
                actions?.toggleImages()
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
            .disabled(actions == nil)

            Button("Toggle Appearance") {
                actions?.toggleAppearance()
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
            .disabled(actions == nil)

            Button("Toggle Full Screen") {
                actions?.toggleFullScreen()
            }
            .keyboardShortcut("f", modifiers: [.command, .control])
            .disabled(actions == nil)

            Divider()

            Button("Copy Clean Text") {
                actions?.copyCleanText()
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(actions?.canCopyDocument != true)

            Button("Copy Markdown") {
                actions?.copyMarkdown()
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
            .disabled(actions?.canCopyDocument != true)
        }
    }
}
