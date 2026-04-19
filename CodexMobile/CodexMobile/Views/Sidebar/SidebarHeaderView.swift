// FILE: SidebarHeaderView.swift
// Purpose: Displays the sidebar app identity header and the inline close affordance for full-width presentation.
// Layer: View Component
// Exports: SidebarHeaderView

import SwiftUI

struct SidebarHeaderView: View {
    var showsCloseButton = false
    var onSettings: () -> Void = {}
    var onClose: () -> Void = {}

    var body: some View {
        HStack(spacing: 10) {
            Text("Harmony")
                .font(AppFont.title3(weight: .semibold))
                .padding(.leading, 8)

            Spacer(minLength: 0)

            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(AppFont.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .adaptiveGlass(.regular, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")

            if showsCloseButton {
                // Mirrors the top-bar menu affordance so full-width sidebar presentations still
                // have an obvious close target after the content shifts completely offscreen.
                Button(action: onClose) {
                    DrawerToggleIcon(edge: .trailing)
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .adaptiveGlass(.regular, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close menu")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

#Preview {
    SidebarHeaderView(showsCloseButton: true)
}
