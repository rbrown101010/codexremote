// FILE: SidebarNewChatButton.swift
// Purpose: Renders the floating New Chat action with loading and disabled states.
// Layer: View Component
// Exports: SidebarNewChatButton

import SwiftUI

struct SidebarNewChatButton: View {
    let isCreatingThread: Bool
    let isEnabled: Bool
    let statusMessage: String?
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticFeedback.shared.triggerImpactFeedback()
            action()
        }) {
            ZStack {
                Circle()
                    .fill(Color.black)

                if isCreatingThread {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(AppFont.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 58, height: 58)
            .shadow(color: Color.black.opacity(0.16), radius: 14, y: 6)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isCreatingThread)
        .opacity(isEnabled ? 1 : 0.38)
        .accessibilityLabel(statusMessage ?? "New chat")
    }
}
// MARK: - Previews
#Preview("Enabled") {
    SidebarNewChatButton(isCreatingThread: false, isEnabled: true, statusMessage: nil) {
        // Preview action
    }
    .padding()
    .frame(width: 260)
}

#Preview("Loading") {
    SidebarNewChatButton(isCreatingThread: true, isEnabled: true, statusMessage: "Preparing owner/repo...") {
        // Preview action
    }
    .padding()
    .frame(width: 260)
}

#Preview("Disabled") {
    SidebarNewChatButton(isCreatingThread: false, isEnabled: false, statusMessage: nil) {
        // Preview action
    }
    .padding()
    .frame(width: 260)
}
