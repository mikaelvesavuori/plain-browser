import AppKit
import SwiftUI

extension View {
    func pointingHandCursor(_ isEnabled: Bool = true) -> some View {
        modifier(PointingHandCursorModifier(isEnabled: isEnabled))
    }

    func hoverIconButton(
        size: CGFloat = 28,
        cornerRadius: CGFloat = 7,
        isDestructive: Bool = false
    ) -> some View {
        modifier(
            HoverIconButtonModifier(
                size: size,
                cornerRadius: cornerRadius,
                isDestructive: isDestructive
            )
        )
    }
}

private struct HoverIconButtonModifier: ViewModifier {
    var size: CGFloat
    var cornerRadius: CGFloat
    var isDestructive: Bool
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .buttonStyle(.plain)
            .foregroundStyle(foregroundColor)
            .frame(width: size, height: size)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: 1)
            }
            .scaleEffect(isHovering && isEnabled ? 1.04 : 1)
            .opacity(isEnabled ? 1 : 0.36)
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .pointingHandCursor(isEnabled)
            .onHover { isHovering = $0 }
    }

    private var foregroundColor: Color {
        if isDestructive && isHovering && isEnabled {
            return Color(nsColor: .systemRed)
        }
        return Color(nsColor: .secondaryLabelColor)
    }

    private var backgroundColor: Color {
        guard isHovering && isEnabled else {
            return .clear
        }
        if isDestructive {
            return Color(nsColor: .systemRed).opacity(0.1)
        }
        return Color.accentColor.opacity(0.1)
    }

    private var borderColor: Color {
        guard isHovering && isEnabled else {
            return .clear
        }
        if isDestructive {
            return Color(nsColor: .systemRed).opacity(0.2)
        }
        return Color.accentColor.opacity(0.22)
    }
}

private struct PointingHandCursorModifier: ViewModifier {
    var isEnabled: Bool
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                guard isEnabled else {
                    popCursorIfNeeded()
                    return
                }

                if hovering {
                    if !isHovering {
                        NSCursor.pointingHand.push()
                        isHovering = true
                    }
                } else {
                    popCursorIfNeeded()
                }
            }
            .onChange(of: isEnabled) { _, enabled in
                if !enabled {
                    popCursorIfNeeded()
                }
            }
            .onDisappear {
                popCursorIfNeeded()
            }
    }

    private func popCursorIfNeeded() {
        if isHovering {
            NSCursor.pop()
            isHovering = false
        }
    }
}
