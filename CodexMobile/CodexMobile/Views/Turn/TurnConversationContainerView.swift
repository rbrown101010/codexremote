// FILE: TurnConversationContainerView.swift
// Purpose: Composes the turn timeline, empty state, composer slot, and top overlays into one focused container.
// Layer: View Component
// Exports: TurnConversationContainerView
// Depends on: SwiftUI, TurnTimelineView

import SwiftUI

struct TurnConversationContainerView: View {
    let threadID: String
    let messages: [CodexMessage]
    let timelineChangeToken: Int
    let activeTurnID: String?
    let isThreadRunning: Bool
    let latestTurnTerminalState: CodexTurnTerminalState?
    let completedTurnIDs: Set<String>
    let stoppedTurnIDs: Set<String>
    let assistantRevertStatesByMessageID: [String: AssistantRevertPresentation]
    let planSessionSource: CodexPlanSessionSource?
    let allowsAssistantPlanFallbackRecovery: Bool
    let threadMessagesForPlanMatching: [CodexMessage]
    let errorMessage: String?
    let composerRecoveryAccessory: AnyView?
    let shouldAnchorToAssistantResponse: Binding<Bool>
    let isScrolledToBottom: Binding<Bool>
    let isComposerFocused: Bool
    let isComposerAutocompletePresented: Bool
    let emptyState: AnyView
    let composer: AnyView
    let structuredPromptReplacementComposer: ((CodexMessage) -> AnyView)?
    let repositoryLoadingToastOverlay: AnyView
    let usageToastOverlay: AnyView
    let isRepositoryLoadingToastVisible: Bool
    let onRetryUserMessage: (String) -> Void
    let onTapAssistantRevert: (CodexMessage) -> Void
    let onTapSubagent: (CodexSubagentThreadPresentation) -> Void
    let onTapOutsideComposer: () -> Void

    @State private var isShowingPinnedPlanSheet = false
    @State private var cachedMessageLayout = TimelineMessageLayout.empty
    @State private var lastMessageLayoutThreadID: String?
    @State private var lastMessageLayoutToken: Int = -1
    @State private var isPinchViewPresented = false
    @State private var didActivatePinchGesture = false
    @State private var didStartPinchPreview = false
    @State private var pinchPresentationProgress: CGFloat = 0
    @State private var pendingPinchScrollTargetID: String?

    // Falls back to a one-off rebuild during first render, then keeps later renders on cached derived state.
    private var messageLayout: TimelineMessageLayout {
        guard lastMessageLayoutThreadID == threadID,
              lastMessageLayoutToken == timelineChangeToken else {
            return Self.buildMessageLayout(
                from: messages,
                planSessionSource: planSessionSource
            )
        }
        return cachedMessageLayout
    }

    private var pinchOverlayProgress: CGFloat {
        isPinchViewPresented ? 1 : pinchPresentationProgress
    }

    private var pinchBackgroundScale: CGFloat {
        1 - (0.025 * pinchOverlayProgress)
    }

    private var pinchBackgroundBlur: CGFloat {
        6 * pinchOverlayProgress
    }

    private var pinchBackgroundSaturation: CGFloat {
        1 - (0.2 * pinchOverlayProgress)
    }

    // Keeps accessory-only chats informative instead of showing a blank viewport.
    private var timelineEmptyState: AnyView {
        guard messageLayout.timelineMessages.isEmpty else {
            return emptyState
        }

        if messageLayout.activeStructuredPromptMessage != nil {
            return AnyView(EmptyView())
        }

        if let pinnedTaskPlanMessage = messageLayout.pinnedTaskPlanMessage {
            let snapshot = PlanAccessorySnapshot(message: pinnedTaskPlanMessage)
            let summary = snapshot.summary.trimmingCharacters(in: .whitespacesAndNewlines)
            return AnyView(
                AccessoryBackedEmptyState(
                    systemImage: snapshot.status.symbolName,
                    tint: snapshot.status.tint,
                    title: snapshot.status == .inProgress ? "Plan in progress" : "Plan ready",
                    summary: summary.isEmpty ? "Codex has prepared a plan for this chat." : summary,
                    detail: "Open the plan card above the composer to review the current steps."
                )
            )
        }

        return emptyState
    }

    // ─── ENTRY POINT ─────────────────────────────────────────────
    var body: some View {
        ZStack(alignment: .top) {
            conversationLayer
                .scaleEffect(pinchBackgroundScale)
                .blur(radius: pinchBackgroundBlur)
                .saturation(pinchBackgroundSaturation)

            if isPinchViewPresented || pinchPresentationProgress > 0 {
                PinchView(messages: messages) {
                    dismissPinchView()
                } onSelectMessage: { message in
                    jumpToMessageFromPinchView(message)
                }
                .opacity(pinchOverlayProgress)
                .scaleEffect(0.93 + (0.07 * pinchOverlayProgress))
                .offset(y: 26 * (1 - pinchOverlayProgress))
                .zIndex(20)
                .simultaneousGesture(pinchDismissGesture)
            }
        }
        .simultaneousGesture(pinchPresentGesture)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: isPinchViewPresented)
        .onAppear {
            rebuildMessageLayoutIfNeeded(force: true)
        }
        .onChange(of: threadID) { _, _ in
            rebuildMessageLayoutIfNeeded(force: true)
        }
        .onChange(of: timelineChangeToken) { _, _ in
            rebuildMessageLayoutIfNeeded()
        }
        .onChange(of: messageLayout.pinnedTaskPlanMessage?.id) { _, newValue in
            if newValue == nil {
                isShowingPinnedPlanSheet = false
            }
        }
        .sheet(isPresented: $isShowingPinnedPlanSheet) {
            if let pinnedTaskPlanMessage = messageLayout.pinnedTaskPlanMessage {
                PlanExecutionSheet(message: pinnedTaskPlanMessage)
            }
        }
    }

    private var conversationLayer: some View {
        ZStack(alignment: .top) {
            timelineLayer
            toastLayer
        }
    }

    private var timelineLayer: some View {
        TurnTimelineView(
            threadID: threadID,
            messages: messageLayout.timelineMessages,
            timelineChangeToken: timelineChangeToken,
            activeTurnID: activeTurnID,
            isThreadRunning: isThreadRunning,
            latestTurnTerminalState: latestTurnTerminalState,
            completedTurnIDs: completedTurnIDs,
            stoppedTurnIDs: stoppedTurnIDs,
            assistantRevertStatesByMessageID: assistantRevertStatesByMessageID,
            planSessionSource: planSessionSource,
            allowsAssistantPlanFallbackRecovery: allowsAssistantPlanFallbackRecovery,
            threadMessagesForPlanMatching: threadMessagesForPlanMatching,
            isRetryAvailable: !isThreadRunning,
            errorMessage: errorMessage,
            hidesErrorMessage: composerRecoveryAccessory != nil,
            shouldAnchorToAssistantResponse: shouldAnchorToAssistantResponse,
            isScrolledToBottom: isScrolledToBottom,
            pendingScrollTargetMessageID: $pendingPinchScrollTargetID,
            isComposerFocused: isComposerFocused,
            isComposerAutocompletePresented: isComposerAutocompletePresented,
            onRetryUserMessage: onRetryUserMessage,
            onTapAssistantRevert: onTapAssistantRevert,
            onTapSubagent: onTapSubagent,
            onTapOutsideComposer: onTapOutsideComposer
        ) {
            timelineEmptyState
        } composer: {
            composerWithPinnedPlanAccessory
        }
    }

    private var toastLayer: some View {
        VStack(spacing: 0) {
            repositoryLoadingToastOverlay
            if !isRepositoryLoadingToastVisible {
                usageToastOverlay
            }
        }
    }

    private var pinchPresentGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard !isPinchViewPresented,
                      !didActivatePinchGesture else {
                    return
                }

                let progress = min(max((1 - value) / 0.22, 0), 1)
                pinchPresentationProgress = progress

                if progress > 0.08, !didStartPinchPreview {
                    didStartPinchPreview = true
                    HapticFeedback.shared.triggerSelectionFeedback()
                }

                guard progress >= 1 else { return }

                didActivatePinchGesture = true
                HapticFeedback.shared.triggerImpactFeedback(style: .medium)
                onTapOutsideComposer()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    pinchPresentationProgress = 1
                    isPinchViewPresented = true
                }
            }
            .onEnded { _ in
                if !isPinchViewPresented {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                        pinchPresentationProgress = 0
                    }
                }

                didActivatePinchGesture = false
                didStartPinchPreview = false
            }
    }

    private var pinchDismissGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard isPinchViewPresented,
                      !didActivatePinchGesture,
                      value > 1.18 else {
                    return
                }

                didActivatePinchGesture = true
                dismissPinchView()
            }
            .onEnded { _ in
                didActivatePinchGesture = false
            }
    }

    private func dismissPinchView() {
        HapticFeedback.shared.triggerImpactFeedback(style: .light)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            isPinchViewPresented = false
            pinchPresentationProgress = 0
        }
    }

    private func jumpToMessageFromPinchView(_ message: CodexMessage) {
        HapticFeedback.shared.triggerImpactFeedback(style: .light)
        pendingPinchScrollTargetID = message.id
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            isPinchViewPresented = false
            pinchPresentationProgress = 0
        }
    }

    // Keeps the active plan discoverable without covering the message timeline.
    private var composerWithPinnedPlanAccessory: some View {
        VStack(spacing: 8) {
            if let pinnedTaskPlanMessage = messageLayout.pinnedTaskPlanMessage {
                PlanExecutionAccessory(message: pinnedTaskPlanMessage) {
                    isShowingPinnedPlanSheet = true
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let composerRecoveryAccessory {
                composerRecoveryAccessory
                    .padding(.horizontal, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let activeStructuredPromptMessage = messageLayout.activeStructuredPromptMessage,
               let structuredPromptReplacementComposer {
                structuredPromptReplacementComposer(activeStructuredPromptMessage)
            } else {
                composer
            }
        }
        .animation(.easeInOut(duration: 0.18), value: messageLayout.pinnedTaskPlanMessage?.id)
        .animation(.easeInOut(duration: 0.18), value: messageLayout.activeStructuredPromptMessage?.id)
    }

    // Rebuilds the plan/timeline split only when the thread or timeline token really changed.
    private func rebuildMessageLayoutIfNeeded(force: Bool = false) {
        guard force
                || lastMessageLayoutThreadID != threadID
                || lastMessageLayoutToken != timelineChangeToken else {
            return
        }

        lastMessageLayoutThreadID = threadID
        lastMessageLayoutToken = timelineChangeToken
        cachedMessageLayout = Self.buildMessageLayout(
            from: messages,
            planSessionSource: planSessionSource
        )
    }

    // Separates pinned plan content from renderable timeline rows in one pass.
    private static func buildMessageLayout(
        from messages: [CodexMessage],
        planSessionSource: CodexPlanSessionSource?
    ) -> TimelineMessageLayout {
        var timelineMessages: [CodexMessage] = []
        timelineMessages.reserveCapacity(messages.count)
        var pinnedTaskPlanMessage: CodexMessage?
        var activeStructuredPromptMessage: CodexMessage?
        let canReplaceComposerWithPrompt = planSessionSource?.isNative == true

        for message in messages {
            if message.shouldDisplayPinnedPlanAccessory {
                pinnedTaskPlanMessage = message
            } else if message.shouldDisplayInlinePlanResult {
                timelineMessages.append(message)
            } else if message.isPlanSystemMessage {
                continue
            } else {
                timelineMessages.append(message)
                if canReplaceComposerWithPrompt,
                   message.shouldDisplayComposerStructuredPrompt {
                    activeStructuredPromptMessage = message
                }
            }
        }

        if let activeStructuredPromptMessage,
           let activeIndex = timelineMessages.lastIndex(where: { $0.id == activeStructuredPromptMessage.id }) {
            timelineMessages.remove(at: activeIndex)
        }

        return TimelineMessageLayout(
            timelineMessages: timelineMessages,
            pinnedTaskPlanMessage: pinnedTaskPlanMessage,
            activeStructuredPromptMessage: activeStructuredPromptMessage
        )
    }
}

private struct TimelineMessageLayout: Equatable {
    let timelineMessages: [CodexMessage]
    let pinnedTaskPlanMessage: CodexMessage?
    let activeStructuredPromptMessage: CodexMessage?

    static let empty = TimelineMessageLayout(
        timelineMessages: [],
        pinnedTaskPlanMessage: nil,
        activeStructuredPromptMessage: nil
    )
}

private struct AccessoryBackedEmptyState: View {
    let systemImage: String
    let tint: Color
    let title: String
    let summary: String
    let detail: String

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(AppFont.system(size: 24, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(tint.opacity(0.12))
                    )

                Text(title)
                    .font(AppFont.title3(weight: .semibold))
                    .multilineTextAlignment(.center)

                Text(summary)
                    .font(AppFont.body())
                    .foregroundStyle(.primary.opacity(0.9))
                    .multilineTextAlignment(.center)

                Text(detail)
                    .font(AppFont.caption())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 320)
            .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

extension CodexMessage {
    var isPlanSystemMessage: Bool {
        role == .system && kind == .plan
    }

    // Hides terminal 3/3-style plans so only genuinely active plans stay pinned above the composer.
    var shouldDisplayPinnedPlanAccessory: Bool {
        guard isPlanSystemMessage,
              resolvedPlanPresentation?.isProgressAccessory == true else {
            return false
        }

        if isStreaming {
            return true
        }

        let steps = planState?.steps ?? []
        guard !steps.isEmpty else {
            return false
        }

        return steps.contains { $0.status != .completed }
    }

    var shouldDisplayInlinePlanResult: Bool {
        guard isPlanSystemMessage,
              resolvedPlanPresentation?.isInlineResultVisible == true,
              !shouldDisplayPinnedPlanAccessory else {
            return false
        }

        return proposedPlan != nil
    }

    var shouldDisplayComposerStructuredPrompt: Bool {
        role == .system && kind == .userInputPrompt && structuredUserInputRequest != nil
    }
}
