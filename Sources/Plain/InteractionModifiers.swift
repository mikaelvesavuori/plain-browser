import AppKit
import SwiftUI

extension View {
    func pointingHandCursor(_ isEnabled: Bool = true) -> some View {
        modifier(PointingHandCursorModifier(isEnabled: isEnabled))
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
