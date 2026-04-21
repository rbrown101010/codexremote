// FILE: PinchView.swift
// Purpose: Prompt-only chat view opened by a two-finger inward pinch gesture.
// Layer: View Component
// Exports: PinchView
// Depends on: SwiftUI, CodexMessage

import SwiftUI

struct PinchView: View {
    let messages: [CodexMessage]
    let onSelectMessage: (CodexMessage) -> Void

    private let scrollBottomAnchorID = "pinch-prompt-scroll-bottom-anchor"
    private static let scrollCoordinateSpaceName = "pinch-prompt-scroll-space"
    private static let topMessageFadeHeight: CGFloat = 108

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
                                .visualEffect { content, geometry in
                                    let minY = geometry.frame(in: .named(Self.scrollCoordinateSpaceName)).minY
                                    let progress = Self.topSofteningProgress(for: minY)
                                    return content
                                        .blur(radius: 3.5 * progress)
                                        .opacity(1 - (0.5 * progress))
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
                    .coordinateSpace(name: Self.scrollCoordinateSpaceName)
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
        .overlay(alignment: .top) {
            topMessageFade
        }
        .overlay(alignment: .bottom) {
            Text("Tap a prompt to jump back")
                .font(AppFont.caption())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 12)
        }
        .accessibilityIdentifier("turn.pinch.promptList")
    }

    private static func topSofteningProgress(for minY: CGFloat) -> CGFloat {
        let fadeStart: CGFloat = 92
        let fadeEnd: CGFloat = 18
        let rawProgress = (fadeStart - minY) / (fadeStart - fadeEnd)
        return min(max(rawProgress, 0), 1)
    }

    private var topMessageFade: some View {
        LinearGradient(
            stops: [
                Gradient.Stop(color: Color(.secondarySystemBackground), location: 0),
                Gradient.Stop(color: Color(.secondarySystemBackground).opacity(0.98), location: 0.48),
                Gradient.Stop(color: Color(.secondarySystemBackground).opacity(0), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
            .frame(height: Self.topMessageFadeHeight)
            .allowsHitTesting(false)
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
        HStack(alignment: .bottom, spacing: 0) {
            Spacer(minLength: 44)

            HStack(alignment: .bottom, spacing: 10) {
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
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(AppFont.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 26, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isExpanded ? "Collapse prompt" : "Expand prompt")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.tertiarySystemFill).opacity(0.8))
                    .stroke(.secondary.opacity(0.08))
            }
        }
    }
}
