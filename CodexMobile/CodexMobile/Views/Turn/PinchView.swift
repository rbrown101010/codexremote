// FILE: PinchView.swift
// Purpose: Prompt-only chat view opened by a two-finger inward pinch gesture.
// Layer: View Component
// Exports: PinchView
// Depends on: SwiftUI, CodexMessage

import SwiftUI

struct PinchView: View {
    let messages: [CodexMessage]
    let onClose: () -> Void
    let onSelectMessage: (CodexMessage) -> Void

    private let scrollBottomAnchorID = "pinch-prompt-scroll-bottom-anchor"

    private var promptMessages: [CodexMessage] {
        messages.filter { message in
            message.role == .user
                && !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if promptMessages.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(promptMessages, id: \.id) { message in
                                PinchPromptRow(
                                    message: message
                                ) {
                                    onSelectMessage(message)
                                }
                            }

                            Color.clear
                                .frame(height: 1)
                                .id(scrollBottomAnchorID)
                                .allowsHitTesting(false)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 58)
                        .padding(.bottom, 20)
                    }
                    .defaultScrollAnchor(.bottom, for: .initialOffset)
                    .scrollDismissesKeyboard(.interactively)
                    .onAppear {
                        DispatchQueue.main.async {
                            proxy.scrollTo(scrollBottomAnchorID, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.secondarySystemBackground))
        .overlay(alignment: .bottom) {
            Text("Tap a prompt to jump back")
                .font(AppFont.caption())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 12)
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(AppFont.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 34, height: 34)
                    .background(.regularMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
            .padding(.trailing, 14)
            .accessibilityLabel("Close Pinch view")
        }
        .accessibilityIdentifier("turn.pinch.promptList")
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
    let message: CodexMessage
    let onSelect: () -> Void

    @State private var isExpanded = false

    private var promptText: String {
        message.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var metadataParts: [String] {
        var parts: [String] = []

        if !message.fileMentions.isEmpty {
            parts.append("\(message.fileMentions.count) file\(message.fileMentions.count == 1 ? "" : "s")")
        }

        if !message.attachments.isEmpty {
            parts.append("\(message.attachments.count) attachment\(message.attachments.count == 1 ? "" : "s")")
        }

        return parts
    }

    private var isExpandable: Bool {
        let explicitLineCount = promptText.reduce(1) { count, character in
            character == "\n" || character == "\r" ? count + 1 : count
        }
        return promptText.count > 220 || explicitLineCount > 3
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                if !metadataParts.isEmpty {
                    Text(metadataParts.joined(separator: " - "))
                        .font(AppFont.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Text(promptText)
                    .font(AppFont.system(size: 14, weight: .regular))
                    .foregroundStyle(.primary)
                    .lineSpacing(2)
                    .lineLimit(isExpanded ? nil : 3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect()
            }

            if isExpandable {
                Button {
                    HapticFeedback.shared.triggerSelectionFeedback()
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                        .font(AppFont.system(size: 18, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "Collapse prompt" : "Expand prompt")
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}
