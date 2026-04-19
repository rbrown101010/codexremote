// FILE: CopyBlockButton.swift
// Purpose: End-of-block accessory that swaps between a running terminal loader and copy action.
// Layer: View Component
// Exports: CopyBlockButton

import SwiftUI
import UIKit

struct CopyBlockButton: View {
    let text: String?
    var isRunning: Bool = false
    @State private var showCopiedFeedback = false

    var body: some View {
        Group {
            if isRunning {
                runningIndicator
            } else if let text {
                Button {
                    HapticFeedback.shared.triggerImpactFeedback(style: .light)
                    UIPasteboard.general.string = text
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showCopiedFeedback = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showCopiedFeedback = false
                        }
                    }
                } label: {
                    copyLabel
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Copy response")
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isRunning)
    }

    private var runningIndicator: some View {
        TerminalRunningIndicator()
    }

    // Keeps the compact copy affordance consistent with the rest of the timeline chrome.
    private var copyLabel: some View {
        HStack(spacing: 0) {
            Group {
                if showCopiedFeedback {
                    Image(systemName: "checkmark")
                        .font(AppFont.system(size: 14, weight: .semibold))
                } else {
                    Image("copy")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                }
            }
            .frame(width: 18, height: 18)
        }
        .foregroundStyle(.secondary)
        .frame(width: 42, height: 42)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

}

#Preview("Default") {
    VStack(alignment: .leading, spacing: 16) {
        Text("This is a sample assistant response with some content that the user might want to copy.")
            .font(AppFont.body())
            .padding(.horizontal, 16)

        CopyBlockButton(text: "This is a sample assistant response with some content that the user might want to copy.")
            .padding(.horizontal, 16)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 20)
}

#Preview("Long block") {
    VStack(alignment: .leading, spacing: 16) {
        Text("Here is the first paragraph of the response.\n\nAnd here is a second paragraph with more detail about the topic at hand.")
            .font(AppFont.body())
            .padding(.horizontal, 16)

        CopyBlockButton(text: "Here is the first paragraph of the response.\n\nAnd here is a second paragraph with more detail about the topic at hand.")
            .padding(.horizontal, 16)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 20)
}

#Preview("Running") {
    VStack(alignment: .leading, spacing: 16) {
        Text("Running a response right now.")
            .font(AppFont.body())
            .padding(.horizontal, 16)

        CopyBlockButton(text: nil, isRunning: true)
            .padding(.horizontal, 16)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 20)
}
