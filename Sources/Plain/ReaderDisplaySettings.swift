import AppKit
import SwiftUI

struct ReaderDisplaySettings: Equatable {
    var fontFamily: ReaderFontFamily
    var textSize: ReaderTextSize

    var signature: String {
        "\(fontFamily.rawValue):\(textSize.rawValue)"
    }

    func scaled(_ value: CGFloat) -> CGFloat {
        value * textSize.scale
    }

    func swiftUIFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: scaled(size), weight: weight, design: fontFamily.swiftUIDesign)
    }

    func regularFont(size: CGFloat) -> NSFont {
        fontFamily.regularFont(size: scaled(size))
    }

    func boldFont(size: CGFloat) -> NSFont {
        fontFamily.boldFont(size: scaled(size))
    }

    func italicFont(size: CGFloat) -> NSFont {
        fontFamily.italicFont(size: scaled(size))
    }
}

enum ReaderFontFamily: String, CaseIterable {
    case serif
    case sans

    var swiftUIDesign: Font.Design {
        switch self {
        case .serif:
            return .serif
        case .sans:
            return .default
        }
    }

    var toolbarIconName: String {
        switch self {
        case .serif:
            return "textformat"
        case .sans:
            return "textformat.abc"
        }
    }

    var toggleHelpText: String {
        switch self {
        case .serif:
            return "Switch to Sans Font"
        case .sans:
            return "Switch to Serif Font"
        }
    }

    var toggled: ReaderFontFamily {
        switch self {
        case .serif:
            return .sans
        case .sans:
            return .serif
        }
    }

    func regularFont(size: CGFloat) -> NSFont {
        switch self {
        case .serif:
            return NSFont(name: "Georgia", size: size)
                ?? NSFont.systemFont(ofSize: size)
        case .sans:
            return NSFont.systemFont(ofSize: size, weight: .regular)
        }
    }

    func boldFont(size: CGFloat) -> NSFont {
        switch self {
        case .serif:
            return NSFont(name: "Georgia-Bold", size: size)
                ?? NSFontManager.shared.convert(regularFont(size: size), toHaveTrait: .boldFontMask)
        case .sans:
            return NSFont.systemFont(ofSize: size, weight: .bold)
        }
    }

    func italicFont(size: CGFloat) -> NSFont {
        switch self {
        case .serif:
            return NSFont(name: "Georgia-Italic", size: size)
                ?? NSFontManager.shared.convert(regularFont(size: size), toHaveTrait: .italicFontMask)
        case .sans:
            return NSFontManager.shared.convert(regularFont(size: size), toHaveTrait: .italicFontMask)
        }
    }
}

enum ReaderTextSize: String, CaseIterable {
    case small
    case medium
    case large
    case extraLarge

    var scale: CGFloat {
        switch self {
        case .small:
            return 0.92
        case .medium:
            return 1.0
        case .large:
            return 1.14
        case .extraLarge:
            return 1.28
        }
    }

    var canDecrease: Bool {
        self != .small
    }

    var canIncrease: Bool {
        self != .extraLarge
    }

    var smaller: ReaderTextSize {
        switch self {
        case .small:
            return .small
        case .medium:
            return .small
        case .large:
            return .medium
        case .extraLarge:
            return .large
        }
    }

    var larger: ReaderTextSize {
        switch self {
        case .small:
            return .medium
        case .medium:
            return .large
        case .large:
            return .extraLarge
        case .extraLarge:
            return .extraLarge
        }
    }

    var cycled: ReaderTextSize {
        switch self {
        case .small:
            return .medium
        case .medium:
            return .large
        case .large:
            return .extraLarge
        case .extraLarge:
            return .small
        }
    }
}
