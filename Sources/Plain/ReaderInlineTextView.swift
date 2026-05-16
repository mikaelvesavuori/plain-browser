import AppKit
import PlainCore
import SwiftUI

struct ParagraphView: View {
    var inline: [InlineElement]
    var readerSettings: ReaderDisplaySettings
    var onOpenLink: (URL) -> Void

    @State private var measuredHeight: CGFloat = 28

    var body: some View {
        GeometryReader { proxy in
            ReaderInlineTextView(
                inline: inline,
                width: proxy.size.width,
                readerSettings: readerSettings,
                measuredHeight: $measuredHeight,
                onOpenLink: onOpenLink
            )
        }
        .frame(height: measuredHeight)
    }
}

private struct ReaderInlineTextView: NSViewRepresentable {
    var inline: [InlineElement]
    var width: CGFloat
    var readerSettings: ReaderDisplaySettings
    @Binding var measuredHeight: CGFloat
    var onOpenLink: (URL) -> Void

    func makeNSView(context: Context) -> LinkAwareTextView {
        let textView = LinkAwareTextView()
        textView.drawsBackground = false
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.importsGraphics = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.linkTextAttributes = [
            .foregroundColor: NSColor.controlAccentColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return textView
    }

    func updateNSView(_ textView: LinkAwareTextView, context: Context) {
        textView.onOpenLink = onOpenLink

        let signature = "\(inline.signature)|\(readerSettings.signature)"
        if textView.renderedSignature != signature {
            textView.textStorage?.setAttributedString(attributedString(from: inline))
            textView.renderedSignature = signature
            textView.needsDisplay = true
        }

        updateLayout(for: textView)
    }

    private func updateLayout(for textView: LinkAwareTextView) {
        let layoutWidth = max(width, 1)
        textView.frame = NSRect(x: 0, y: 0, width: layoutWidth, height: measuredHeight)
        textView.textContainer?.containerSize = NSSize(
            width: layoutWidth,
            height: .greatestFiniteMagnitude
        )

        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return
        }

        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        let nextHeight = max(ceil(usedRect.height), 1)

        if abs(measuredHeight - nextHeight) > 0.5 {
            DispatchQueue.main.async {
                measuredHeight = nextHeight
            }
        }
    }

    private func attributedString(from inline: [InlineElement]) -> NSAttributedString {
        let output = NSMutableAttributedString()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = readerSettings.scaled(7)
        paragraphStyle.paragraphSpacing = 0
        paragraphStyle.lineHeightMultiple = 1.03
        paragraphStyle.lineBreakMode = .byWordWrapping

        let baseFont = readerSettings.regularFont(size: 18.2)
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]

        func append(_ text: String, attributes: [NSAttributedString.Key: Any] = [:]) {
            var merged = baseAttributes
            attributes.forEach { key, value in
                merged[key] = value
            }
            output.append(NSAttributedString(string: text, attributes: merged))
        }

        for element in inline {
            switch element {
            case .text(let text):
                append(text)
            case .strong(let text):
                append(text, attributes: [.font: readerSettings.boldFont(size: 18.2)])
            case .emphasis(let text):
                append(text, attributes: [.font: readerSettings.italicFont(size: 18.2)])
            case .code(let text):
                append(
                    text,
                    attributes: [
                        .font: NSFont.monospacedSystemFont(ofSize: readerSettings.scaled(16.2), weight: .regular),
                        .foregroundColor: NSColor.secondaryLabelColor,
                        .backgroundColor: NSColor.controlBackgroundColor.withAlphaComponent(0.72)
                    ]
                )
            case .link(let text, let url):
                append(
                    text,
                    attributes: [
                        .link: url,
                        .cursor: NSCursor.pointingHand,
                        .foregroundColor: NSColor.controlAccentColor,
                        .underlineStyle: NSUnderlineStyle.single.rawValue
                    ]
                )
            case .lineBreak:
                append("\n")
            }
        }

        return output
    }
}

private final class LinkAwareTextView: NSTextView {
    var onOpenLink: ((URL) -> Void)?
    var renderedSignature = ""
    private var linkTrackingArea: NSTrackingArea?

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRectsForLinks()
    }

    override func updateTrackingAreas() {
        if let linkTrackingArea {
            removeTrackingArea(linkTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved],
            owner: self
        )
        addTrackingArea(trackingArea)
        linkTrackingArea = trackingArea

        super.updateTrackingAreas()
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)

        let point = convert(event.locationInWindow, from: nil)
        if linkURL(at: point) != nil {
            NSCursor.pointingHand.set()
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let url = linkURL(at: point) {
            onOpenLink?(url)
            return
        }

        super.mouseDown(with: event)
    }

    private func addCursorRectsForLinks() {
        guard let textStorage,
              let layoutManager,
              let textContainer else {
            return
        }

        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.enumerateAttribute(.link, in: fullRange) { value, range, _ in
            guard value != nil else {
                return
            }

            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: range,
                actualCharacterRange: nil
            )

            layoutManager.enumerateEnclosingRects(
                forGlyphRange: glyphRange,
                withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                in: textContainer
            ) { [weak self] rect, _ in
                guard let self else {
                    return
                }

                let cursorRect = rect
                    .offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
                    .insetBy(dx: -1, dy: -1)
                addCursorRect(cursorRect, cursor: .pointingHand)
            }
        }
    }

    private func linkURL(at point: NSPoint) -> URL? {
        guard let textStorage,
              let layoutManager,
              let textContainer,
              textStorage.length > 0 else {
            return nil
        }

        let textPoint = NSPoint(
            x: point.x - textContainerOrigin.x,
            y: point.y - textContainerOrigin.y
        )
        guard textPoint.x >= 0, textPoint.y >= 0 else {
            return nil
        }

        let glyphIndex = layoutManager.glyphIndex(for: textPoint, in: textContainer)
        guard glyphIndex < layoutManager.numberOfGlyphs else {
            return nil
        }

        let glyphRect = layoutManager.boundingRect(
            forGlyphRange: NSRange(location: glyphIndex, length: 1),
            in: textContainer
        )
        guard glyphRect.insetBy(dx: -2, dy: -2).contains(textPoint) else {
            return nil
        }

        let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        guard characterIndex < textStorage.length else {
            return nil
        }

        return textStorage.attribute(.link, at: characterIndex, effectiveRange: nil) as? URL
    }
}

private extension Array where Element == InlineElement {
    var signature: String {
        map { element in
            switch element {
            case .text(let text):
                return "t:\(text)"
            case .strong(let text):
                return "b:\(text)"
            case .emphasis(let text):
                return "i:\(text)"
            case .code(let text):
                return "c:\(text)"
            case .link(let text, let url):
                return "l:\(text)|\(url.absoluteString)"
            case .lineBreak:
                return "br"
            }
        }
        .joined(separator: "\u{1F}")
    }
}
