// FILE: PinchView.swift
// Purpose: Prompt-only chat view opened by a two-finger inward pinch gesture.
// Layer: View Component
// Exports: PinchView
// Depends on: SwiftUI, CodexMessage

import SwiftUI

struct PinchView: View {
    let messages: [CodexMessage]
    let onClose: () -> Void

    private var promptMessages: [CodexMessage] {
        messages.filter { message in
            message.role == .user
                && !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if promptMessages.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(promptMessages.enumerated()), id: \.element.id) { index, message in
                            PinchPromptRow(
                                index: index + 1,
                                message: message
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.secondarySystemBackground))
        .overlay(alignment: .bottom) {
            Text("Pinch out or tap Close to return to chat")
                .font(AppFont.caption())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 12)
        }
        .accessibilityIdentifier("turn.pinch.promptList")
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pinch")
                    .font(AppFont.title3(weight: .semibold))
                Text("\(promptMessages.count) sent prompt\(promptMessages.count == 1 ? "" : "s")")
                    .font(AppFont.caption())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(AppFont.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 34, height: 34)
                    .background(Color(.tertiarySystemBackground), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close Pinch view")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(.regularMaterial)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "text.bubble")
                .font(AppFont.system(size: 30, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 62, height: 62)
                .background(Color(.tertiarySystemBackground), in: Circle())

            Text("No prompts yet")
                .font(AppFont.title3(weight: .semibold))

            Text("Messages you send in this chat will appear here after you pinch in.")
                .font(AppFont.body())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PinchPromptRow: View {
    let index: Int
    let message: CodexMessage

    private var promptText: String {
        message.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var metadata: String {
        var parts = ["#\(index)"]

        if !message.fileMentions.isEmpty {
            parts.append("\(message.fileMentions.count) file\(message.fileMentions.count == 1 ? "" : "s")")
        }

        if !message.attachments.isEmpty {
            parts.append("\(message.attachments.count) attachment\(message.attachments.count == 1 ? "" : "s")")
        }

        return parts.joined(separator: " - ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(metadata)
                .font(AppFont.caption(weight: .medium))
                .foregroundStyle(.secondary)

            Text(promptText)
                .font(AppFont.body())
                .foregroundStyle(.primary)
                .lineSpacing(3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}
