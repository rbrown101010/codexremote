// FILE: OnboardingSetupPromptPage.swift
// Purpose: Single Codex prompt page for installing and starting Chorus Remote pairing.
// Layer: View
// Exports: OnboardingSetupPromptPage
// Depends on: SwiftUI, AppFont

import SwiftUI

struct OnboardingSetupPromptPage: View {
    @State private var copied = false

    private let setupPrompt = """
    Set up Chorus Remote on this Mac.

    Run:

    npm install -g @openai/codex@latest
    npm install -g remodex@latest
    remodex up

    When Remodex prints a QR code or pairing code, show it in a local browser page so I can scan it from my iPhone.
    """

    var body: some View {
        ZStack(alignment: .top) {
            Color(.secondarySystemBackground)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                Spacer(minLength: 42)

                header

                promptCard

                Spacer(minLength: 120)
            }
            .padding(.horizontal, 24)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Copy setup prompt")
                .font(AppFont.title2(weight: .semibold))
                .foregroundStyle(.primary)

            Text("Paste it into Codex on your Mac.")
                .font(AppFont.body())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Text("Prompt")
                    .font(AppFont.caption(weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    UIPasteboard.general.string = setupPrompt
                    HapticFeedback.shared.triggerImpactFeedback(style: .light)
                    withAnimation(.easeInOut(duration: 0.2)) { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeInOut(duration: 0.2)) { copied = false }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12, weight: .semibold))
                        Text(copied ? "Copied" : "Copy")
                            .font(AppFont.caption(weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.black, in: Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Text(setupPrompt)
                .font(AppFont.mono(.caption))
                .foregroundStyle(.primary)
                .lineSpacing(4)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

#Preview {
    ZStack {
        Color(.secondarySystemBackground).ignoresSafeArea()
        OnboardingSetupPromptPage()
    }
}
