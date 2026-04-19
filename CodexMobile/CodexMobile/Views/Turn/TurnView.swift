// FILE: TurnView.swift
// Purpose: Orchestrates turn screen composition, wiring service state to timeline + composer components.
// Layer: View
// Exports: TurnView
// Depends on: CodexService, TurnViewModel, TurnConversationContainerView, TurnComposerHostView, TurnViewAlertModifier, TurnViewLifecycleModifier

import SwiftUI
import PhotosUI
import UIKit
import WebKit

struct TurnView: View {
    let thread: CodexThread
    let isWakingMacDisplayRecovery: Bool

    @Environment(CodexService.self) private var codex
    @Environment(\.openURL) private var openURL
    @Environment(\.reconnectAction) private var reconnectAction
    @Environment(\.wakeMacDisplayAction) private var wakeMacDisplayAction
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = TurnViewModel()
    @State private var isInputFocused = false
    @State private var isShowingThreadPathSheet = false
    @State private var isShowingThreadPathPreview = false
    @State private var threadPathPreviewDismissTask: Task<Void, Never>?
    @State private var isShowingStatusSheet = false
    @State private var isLoadingRepositoryDiff = false
    @State private var repositoryDiffPresentation: TurnDiffPresentation?
    @State private var assistantRevertSheetState: AssistantRevertSheetState?
    @State private var alertApprovalRequest: CodexApprovalRequest?
    @State private var isApprovalAlertPresented = false
    @State private var isShowingMacHandoffConfirm = false
    @State private var isShowingWorktreeHandoff = false
    @State private var isShowingForkWorktree = false
    @State private var macHandoffErrorMessage: String?
    @State private var isHandingOffToMac = false
    @State private var isStartingSiblingChat = false
    @State private var isForkingThread = false
    @State private var checkedOutElsewhereAlert: CheckedOutElsewhereAlert?
    @State private var isVoiceRecording = false
    @State private var isVoicePreflighting = false
    @State private var voicePreflightGeneration = 0
    @State private var isVoiceTranscribing = false
    @State private var hasTriggeredVoiceAutoStop = false
    @State private var voiceRecoveryReason: CodexVoiceFailureReason?
    @State private var isShowingVoiceSetupSheet = false
    @State private var externalBrowserPresentation: ExternalBrowserPresentation?
    @StateObject private var voiceTranscriptionManager = GPTVoiceTranscriptionManager()

    // ─── ENTRY POINT ─────────────────────────────────────────────
    var body: some View {
        let resolvedThread = currentResolvedThread
        let timelineState = codex.timelineState(for: thread.id)
        let renderSnapshot = timelineState.renderSnapshot
        let activeTurnID = renderSnapshot.activeTurnID
        let planSessionSource = codex.currentPlanSessionSource(for: thread.id)
        let gitWorkingDirectory = resolvedThread.gitWorkingDirectory
        let isThreadRunning = renderSnapshot.isThreadRunning
        let isEmptyThread = renderSnapshot.messages.isEmpty
        let threadDisplayPhase = codex.threadDisplayPhase(threadId: thread.id)
        // Keep the service-owned loading vs empty-state decision intact while
        // history hydration catches up for previously active conversations.
        let resolvedEmptyConversationState = resolvedEmptyState(for: threadDisplayPhase)
        let showsGitControls = codex.isConnected && gitWorkingDirectory != nil
        let isWorktreeProject = resolvedThread.isManagedWorktreeProject
        let isComposerAutocompletePresented = viewModel.isFileAutocompleteVisible
            || viewModel.isSkillAutocompleteVisible
            || viewModel.slashCommandPanelState != .hidden
        let isWorktreeHandoffAvailable = isWorktreeHandoffAvailable(
            isThreadRunning: isThreadRunning,
            gitWorkingDirectory: gitWorkingDirectory
        )
        let canHandOffToWorktree = canHandOffToWorktree(
            isThreadRunning: isThreadRunning,
            gitWorkingDirectory: gitWorkingDirectory
        )
        let toolbarNavigationContext = threadNavigationContext(for: resolvedThread)
        let toolbarWorktreeHandoffTitle = isWorktreeProject ? "Hand off to Local" : "Hand off to Worktree"
        let isGitActionEnabled = canRunGitAction(
            isThreadRunning: isThreadRunning,
            gitWorkingDirectory: gitWorkingDirectory
        )
        let disabledGitActions: Set<TurnGitActionKind> = viewModel.canCreatePullRequest ? [] : [.createPR]
        let onTapMacHandoff: (() -> Void)? = codex.isConnected ? {
            isShowingMacHandoffConfirm = true
        } : nil
        let onTapWorktreeHandoff: (() -> Void)? = showsGitControls ? {
            handleWorktreeHandoffTap(currentThread: resolvedThread)
        } : nil
        let onTapNewChat: (() -> Void)? = codex.isConnected && !isWorktreeProject ? {
            startSiblingChat()
        } : nil
        let onTapRepoDiff: (() -> Void)? = showsGitControls ? {
            presentRepositoryDiff(workingDirectory: gitWorkingDirectory)
        } : nil

        return TurnConversationContainerView(
                threadID: thread.id,
                messages: renderSnapshot.messages,
                timelineChangeToken: renderSnapshot.timelineChangeToken,
                activeTurnID: activeTurnID,
                isThreadRunning: isThreadRunning,
                latestTurnTerminalState: renderSnapshot.latestTurnTerminalState,
                completedTurnIDs: renderSnapshot.completedTurnIDs,
                stoppedTurnIDs: renderSnapshot.stoppedTurnIDs,
                assistantRevertStatesByMessageID: renderSnapshot.assistantRevertStatesByMessageID,
                planSessionSource: planSessionSource,
                allowsAssistantPlanFallbackRecovery: planSessionSource == .compatibilityFallback,
                threadMessagesForPlanMatching: renderSnapshot.planMatchingMessages,
                errorMessage: nil,
                composerRecoveryAccessory: composerRecoveryAccessory,
                shouldAnchorToAssistantResponse: shouldAnchorToAssistantResponseBinding,
                isScrolledToBottom: isScrolledToBottomBinding,
                isComposerFocused: isInputFocused,
                isComposerAutocompletePresented: isComposerAutocompletePresented,
                emptyState: resolvedEmptyConversationState,
                composer: AnyView(composerWithSubagentAccessory(
                    currentThread: resolvedThread,
                    activeTurnID: activeTurnID,
                    isThreadRunning: isThreadRunning,
                    isEmptyThread: isEmptyThread,
                    isWorktreeProject: isWorktreeProject,
                    showsGitControls: showsGitControls,
                    gitWorkingDirectory: gitWorkingDirectory
                )),
                structuredPromptReplacementComposer: { message in
                    AnyView(composerStructuredPromptReplacement(message: message))
                },
                repositoryLoadingToastOverlay: AnyView(EmptyView()),
                usageToastOverlay: AnyView(EmptyView()),
                isRepositoryLoadingToastVisible: false,
                onRetryUserMessage: { messageText in
                    viewModel.input = messageText
                    isInputFocused = true
                },
                onTapAssistantRevert: { message in
                    startAssistantRevertPreview(message: message, gitWorkingDirectory: gitWorkingDirectory)
                },
                onTapSubagent: { subagent in
                    openThread(subagent.threadId)
                },
                onTapOutsideComposer: {
                    guard isInputFocused else { return }
                    isInputFocused = false
                    viewModel.clearComposerAutocomplete()
                }
            )
        .environment(\.openURL, conversationOpenURLAction)
        .environment(\.inlineCommitAndPushAction, showsGitControls ? {
            viewModel.inlineCommitAndPush(
                codex: codex,
                workingDirectory: gitWorkingDirectory,
                threadID: thread.id
            )
        } as (() -> Void)? : nil)
        .environment(\.inlineGitAction, showsGitControls ? { action in
            viewModel.triggerGitAction(
                action,
                codex: codex,
                workingDirectory: gitWorkingDirectory,
                threadID: thread.id,
                activeTurnID: activeTurnID
            )
        } as ((TurnGitActionKind) -> Void)? : nil)
        .environment(\.inlineGitRunningAction, viewModel.runningGitAction)
        .environment(\.inlineCommitAndPushPhase, viewModel.inlineCommitAndPushPhase)
        .navigationTitle(resolvedThread.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            TurnToolbarContent(
                displayTitle: resolvedThread.displayTitle,
                navigationContext: toolbarNavigationContext,
                showsSettingsAttention: showsToolbarSettingsAttention,
                settingsStatusText: toolbarSettingsStatusText,
                canReconnectToMac: codex.hasReconnectCandidate && !codex.isConnected,
                isReconnectingToMac: codex.isConnecting || isRetryingConnectionRecovery,
                canWakeMacScreen: shouldOfferWakeSavedMacDisplayAction,
                showsThreadActions: codex.isConnected,
                isHandingOffToMac: isHandingOffToMac,
                isStartingNewChat: isStartingSiblingChat,
                canHandOffToWorktree: canHandOffToWorktree,
                worktreeHandoffTitle: toolbarWorktreeHandoffTitle,
                isCreatingGitWorktree: viewModel.isCreatingGitWorktree,
                repoDiffTotals: viewModel.gitRepoSync?.repoDiffTotals,
                isLoadingRepoDiff: isLoadingRepositoryDiff,
                showsGitActions: showsGitControls,
                isGitActionEnabled: isGitActionEnabled,
                disabledGitActions: disabledGitActions,
                isRunningGitAction: viewModel.isRunningGitAction,
                showsDiscardRuntimeChangesAndSync: viewModel.shouldShowDiscardRuntimeChangesAndSync,
                gitSyncState: viewModel.gitSyncState,
                onTapMacHandoff: onTapMacHandoff,
                onTapWorktreeHandoff: onTapWorktreeHandoff,
                onTapNewChat: onTapNewChat,
                onTapRepoDiff: onTapRepoDiff,
                onTapReconnectToMac: reconnectAction,
                onTapWakeMacScreen: wakeMacDisplayAction,
                onGitAction: { action in
                    handleGitActionSelection(
                        action,
                        isThreadRunning: isThreadRunning,
                        gitWorkingDirectory: gitWorkingDirectory
                    )
                },
                isShowingPathSheet: $isShowingThreadPathSheet,
                isShowingPathPreview: $isShowingThreadPathPreview,
                onTapTitle: showThreadPathPreview
            )
        }
        .overlay {
            if isShowingWorktreeHandoff {
                TurnWorktreeHandoffOverlay(
                    mode: .handoff,
                    preferredBaseBranch: preferredWorktreeBaseBranch,
                    isHandoffAvailable: isWorktreeHandoffAvailable,
                    isSubmitting: viewModel.isCreatingGitWorktree,
                    onClose: { isShowingWorktreeHandoff = false },
                    onSubmit: { branchName, baseBranch in
                        submitWorktreeHandoff(
                            branchName: branchName,
                            baseBranch: baseBranch,
                            gitWorkingDirectory: gitWorkingDirectory,
                            activeTurnID: activeTurnID
                        )
                    }
                )
                .transition(.opacity)
            }

            if isShowingForkWorktree {
                TurnWorktreeHandoffOverlay(
                    mode: .fork,
                    preferredBaseBranch: preferredWorktreeBaseBranch,
                    isHandoffAvailable: isWorktreeHandoffAvailable,
                    isSubmitting: viewModel.isCreatingGitWorktree || isForkingThread,
                    onClose: { isShowingForkWorktree = false },
                    onSubmit: { branchName, baseBranch in
                        submitForkIntoNewWorktree(
                            branchName: branchName,
                            baseBranch: baseBranch,
                            gitWorkingDirectory: gitWorkingDirectory,
                            activeTurnID: activeTurnID
                        )
                    }
                )
                .transition(.opacity)
            }
        }
        .fullScreenCover(isPresented: isCameraPresentedBinding) {
            CameraImagePicker { data in
                viewModel.enqueueCapturedImageData(data, codex: codex)
            }
            .ignoresSafeArea()
        }
        .photosPicker(
            isPresented: isPhotoPickerPresentedBinding,
            selection: photoPickerItemsBinding,
            maxSelectionCount: max(1, viewModel.remainingAttachmentSlots),
            matching: .images,
            preferredItemEncoding: .automatic
        )
        .turnViewLifecycle(
            taskID: thread.id,
            activeTurnID: activeTurnID,
            isThreadRunning: isThreadRunning,
            isConnected: codex.isConnected,
            scenePhase: scenePhase,
            approvalRequestChangeToken: approvalRequestChangeToken,
            photoPickerItems: viewModel.photoPickerItems,
            onTask: {
                await prepareThreadIfReady(gitWorkingDirectory: gitWorkingDirectory)
            },
            onInitialAppear: {
                handleInitialAppear(activeTurnID: activeTurnID)
            },
            onPhotoPickerItemsChanged: { newItems in
                handlePhotoPickerItemsChanged(newItems)
            },
            onActiveTurnChanged: { newValue in
                if newValue != nil {
                    viewModel.clearComposerAutocomplete()
                }
            },
            onThreadRunningChanged: { wasRunning, isRunning in
                guard wasRunning, !isRunning else { return }
                viewModel.flushQueueIfPossible(codex: codex, threadID: thread.id)
                guard showsGitControls else { return }
                viewModel.refreshGitBranchTargets(
                    codex: codex,
                    workingDirectory: gitWorkingDirectory,
                    threadID: thread.id
                )
            },
            onConnectionChanged: { wasConnected, isConnected in
                if !isConnected {
                    cancelVoiceRecordingIfNeeded()
                    invalidatePendingVoicePreflight()
                    clearVoiceRecovery()
                    return
                }

                clearVoiceRecovery()
                guard !wasConnected, isConnected else { return }
                viewModel.flushQueueIfPossible(codex: codex, threadID: thread.id)
                guard showsGitControls else { return }
                viewModel.refreshGitBranchTargets(
                    codex: codex,
                    workingDirectory: gitWorkingDirectory,
                    threadID: thread.id
                )
            },
            onScenePhaseChanged: { phase in
                guard phase != .active else { return }
                cancelVoiceRecordingIfNeeded()
                invalidatePendingVoicePreflight()
            },
            onApprovalRequestChanged: {
                syncApprovalAlertPresentation()
            }
        )
        .onDisappear {
            cancelVoiceRecordingIfNeeded()
            invalidatePendingVoicePreflight()
            clearVoiceRecovery()
            viewModel.cancelTransientTasks()
            viewModel.clearComposerAutocomplete()
        }
        .onChange(of: isInputFocused) { _, isFocused in
            guard !isFocused else { return }
            viewModel.clearComposerAutocomplete()
        }
        .onChange(of: renderSnapshot.repoRefreshSignal) { _, newValue in
            guard showsGitControls, newValue != nil else { return }
            viewModel.scheduleGitStatusRefresh(
                codex: codex,
                workingDirectory: gitWorkingDirectory,
                threadID: thread.id
            )
        }
        .onChange(of: renderSnapshot.timelineChangeToken) { _, _ in
            viewModel.reconcileDismissedStructuredPlanPrompts(messages: renderSnapshot.messages, codex: codex)
        }
        .onReceive(voiceTranscriptionManager.$recordingDuration) { duration in
            guard isVoiceRecording,
                  !isVoiceTranscribing,
                  !hasTriggeredVoiceAutoStop,
                  duration >= voiceAutoStopThreshold else {
                return
            }

            hasTriggeredVoiceAutoStop = true
            Task { @MainActor in
                await stopVoiceTranscription()
            }
        }
        .sheet(isPresented: $isShowingThreadPathSheet) {
            if let context = threadNavigationContext(for: resolvedThread) {
                TurnThreadPathSheet(
                    context: context,
                    threadTitle: resolvedThread.displayTitle,
                    onRenameThread: { newName in
                        codex.renameThread(thread.id, name: newName)
                    }
                )
            }
        }
        .sheet(isPresented: $isShowingStatusSheet) {
            TurnStatusSheet(
                contextWindowUsage: codex.contextWindowUsageByThread[thread.id],
                rateLimitBuckets: codex.rateLimitBuckets,
                isLoadingRateLimits: codex.isLoadingRateLimits,
                rateLimitsErrorMessage: codex.rateLimitsErrorMessage
            )
        }
        .sheet(isPresented: $isShowingVoiceSetupSheet) {
            GPTVoiceSetupSheet()
        }
        .fullScreenCover(item: $externalBrowserPresentation) { presentation in
            TurnExternalBrowserSheet(url: presentation.url)
        }
        .sheet(item: $repositoryDiffPresentation) { presentation in
            TurnDiffSheet(
                title: presentation.title,
                entries: presentation.entries,
                bodyText: presentation.bodyText,
                messageID: presentation.messageID
            )
        }
        .sheet(isPresented: assistantRevertSheetPresentedBinding) {
            if let assistantRevertSheetState {
                AssistantRevertSheet(
                    state: assistantRevertSheetState,
                    onClose: { self.assistantRevertSheetState = nil },
                    onConfirm: {
                        confirmAssistantRevert(gitWorkingDirectory: gitWorkingDirectory)
                    }
                )
            }
        }
        .turnViewAlerts(
            alertApprovalRequest: $alertApprovalRequest,
            isApprovalAlertPresented: $isApprovalAlertPresented,
            isShowingNothingToCommitAlert: isShowingNothingToCommitAlertBinding,
            gitSyncAlert: gitSyncAlertBinding,
            isShowingMacHandoffConfirm: $isShowingMacHandoffConfirm,
            macHandoffErrorMessage: $macHandoffErrorMessage,
            onDeclineApproval: { request in
                viewModel.decline(request, codex: codex) { didSucceed in
                    if didSucceed {
                        syncApprovalAlertPresentation()
                    } else {
                        restoreApprovalAlert(afterFailureOf: request)
                    }
                }
            },
            onApproveApproval: { request in
                viewModel.approve(request, codex: codex) { didSucceed in
                    if didSucceed {
                        syncApprovalAlertPresentation()
                    } else {
                        restoreApprovalAlert(afterFailureOf: request)
                    }
                }
            },
            onConfirmGitSyncAction: { alertAction in
                viewModel.confirmGitSyncAlertAction(
                    alertAction,
                    codex: codex,
                    workingDirectory: gitWorkingDirectory,
                    threadID: thread.id,
                    activeTurnID: codex.activeTurnID(for: thread.id)
                )
            },
            onDismissGitSyncAlert: {
                viewModel.dismissGitSyncAlert()
            },
            onConfirmMacHandoff: {
                continueOnMac()
            }
        )
        .alert(
            checkedOutElsewhereAlert?.title ?? "Branch already open elsewhere",
            isPresented: checkedOutElsewhereAlertIsPresented,
            presenting: checkedOutElsewhereAlert
        ) { alert in
            Button("Close", role: .cancel) {
                checkedOutElsewhereAlert = nil
            }

            if let threadID = alert.threadID {
                Button("Open Chat") {
                    checkedOutElsewhereAlert = nil
                    openThread(threadID)
                }
            }
        } message: { alert in
            Text(alert.message)
        }
    }

    // Reuses the shared recovery-card slot for both transport reconnects and voice-specific guidance.
    private var composerRecoveryAccessory: AnyView? {
        if let voiceRecoveryPresentation {
            return AnyView(
                ConnectionRecoveryCard(snapshot: voiceRecoveryPresentation.snapshot) {
                    handleVoiceRecoveryAction(voiceRecoveryPresentation.action)
                }
            )
        }
        return nil
    }

    private var voiceRecoveryPresentation: VoiceRecoveryPresentation? {
        guard let voiceRecoveryReason else {
            return nil
        }

        guard let resolvedReason = codex.resolveVoiceRecoveryReason(voiceRecoveryReason) else {
            return nil
        }

        return buildVoiceRecoveryPresentation(for: resolvedReason)
    }

    private var connectionRecoverySnapshot: ConnectionRecoverySnapshot? {
        TurnConnectionRecoverySnapshotBuilder.makeSnapshot(
            hasReconnectCandidate: codex.hasReconnectCandidate,
            isConnected: codex.isConnected,
            secureConnectionState: codex.secureConnectionState,
            showsWakeSavedMacDisplayAction: shouldOfferWakeSavedMacDisplayAction,
            isWakingMacDisplayRecovery: isWakingMacDisplayRecovery,
            isConnecting: codex.isConnecting,
            shouldAutoReconnectOnForeground: codex.shouldAutoReconnectOnForeground,
            isRetryingConnectionRecovery: isRetryingConnectionRecovery,
            lastErrorMessage: codex.lastErrorMessage
        )
    }

    private var canWakeSavedMacDisplay: Bool {
        codex.canWakePreferredMacDisplay
    }

    // Matches the root fallback gate so the turn card only offers wake after the silent attempt already ran.
    private var shouldOfferWakeSavedMacDisplayAction: Bool {
        canWakeSavedMacDisplay && wakeMacDisplayAction != nil
    }

    private var isRetryingConnectionRecovery: Bool {
        if case .retrying = codex.connectionRecoveryState {
            return true
        }
        return false
    }

    private var showsToolbarSettingsAttention: Bool {
        if let error = codex.lastErrorMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
           !error.isEmpty {
            return true
        }

        if shouldOfferWakeSavedMacDisplayAction || isWakingMacDisplayRecovery {
            return true
        }

        if isRetryingConnectionRecovery || codex.isConnecting || codex.shouldAutoReconnectOnForeground {
            return true
        }

        return codex.hasReconnectCandidate && !codex.isConnected
    }

    private var toolbarSettingsStatusText: String? {
        if let error = codex.lastErrorMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
           !error.isEmpty {
            return error
        }

        if isWakingMacDisplayRecovery {
            return "Trying to wake your Mac display."
        }

        if shouldOfferWakeSavedMacDisplayAction {
            return "Wake your Mac screen to keep this chat in sync."
        }

        if isRetryingConnectionRecovery || codex.isConnecting || codex.shouldAutoReconnectOnForeground {
            return "Trying to reconnect to your Mac."
        }

        if codex.hasReconnectCandidate && !codex.isConnected {
            return "Reconnect to your Mac to keep this chat in sync."
        }

        return nil
    }

    // MARK: - Bindings

    private var shouldAnchorToAssistantResponseBinding: Binding<Bool> {
        Binding(
            get: { viewModel.shouldAnchorToAssistantResponse },
            set: { viewModel.shouldAnchorToAssistantResponse = $0 }
        )
    }

    private var conversationOpenURLAction: OpenURLAction {
        OpenURLAction { url in
            handleConversationOpenURL(url)
        }
    }

    private var isScrolledToBottomBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isScrolledToBottom },
            set: { viewModel.isScrolledToBottom = $0 }
        )
    }

    private func handleConversationOpenURL(_ url: URL) -> OpenURLAction.Result {
        guard ExternalBrowserLinkRouter.shouldPresentInAppBrowser(for: url) else {
            return .systemAction
        }

        HapticFeedback.shared.triggerImpactFeedback(style: .light)
        externalBrowserPresentation = ExternalBrowserPresentation(url: url)
        return .handled
    }

    // Fetches the repo-wide local patch on demand so the toolbar pill opens the same diff UI as turn changes.
    private func presentRepositoryDiff(workingDirectory: String?) {
        guard !isLoadingRepositoryDiff else { return }
        isLoadingRepositoryDiff = true

        Task { @MainActor in
            defer { isLoadingRepositoryDiff = false }

            let gitService = GitActionsService(codex: codex, workingDirectory: workingDirectory)

            do {
                let result = try await gitService.diff()
                guard let presentation = TurnDiffPresentationBuilder.repositoryPresentation(from: result.patch) else {
                    viewModel.gitSyncAlert = TurnGitSyncAlert(
                        title: "Git Error",
                        message: "There are no repository changes to show.",
                        action: .dismissOnly
                    )
                    return
                }
                repositoryDiffPresentation = presentation
            } catch let error as GitActionsError {
                viewModel.gitSyncAlert = TurnGitSyncAlert(
                    title: "Git Error",
                    message: error.errorDescription ?? "Could not load repository changes.",
                    action: .dismissOnly
                )
            } catch {
                viewModel.gitSyncAlert = TurnGitSyncAlert(
                    title: "Git Error",
                    message: error.localizedDescription,
                    action: .dismissOnly
                )
            }
        }
    }

    private var isShowingNothingToCommitAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isShowingNothingToCommitAlert },
            set: { viewModel.isShowingNothingToCommitAlert = $0 }
        )
    }

    // Opens the local session summary and refreshes both thread context usage and rate limits.
    private func presentStatusSheet() {
        isShowingStatusSheet = true

        Task {
            await codex.refreshUsageStatus(threadId: thread.id)
        }
    }

    private func continueOnMac() {
        guard !isHandingOffToMac else { return }
        isHandingOffToMac = true

        Task { @MainActor in
            defer { isHandingOffToMac = false }

            do {
                let handoffService = DesktopHandoffService(codex: codex)
                try await handoffService.continueOnMac(threadId: thread.id)
            } catch {
                macHandoffErrorMessage = error.localizedDescription
            }
        }
    }

    // Starts a sibling chat scoped to the same cwd as the current thread.
    private func startSiblingChat() {
        Task { @MainActor in
            guard !isStartingSiblingChat else { return }
            guard !currentResolvedThread.isManagedWorktreeProject else { return }
            isStartingSiblingChat = true
            defer { isStartingSiblingChat = false }

            do {
                _ = try await codex.startThreadIfReady(preferredProjectPath: resolvedProjectPathForFollowUpThread())
            } catch {
                if codex.lastErrorMessage?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                    codex.lastErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private var gitSyncAlertBinding: Binding<TurnGitSyncAlert?> {
        Binding(
            get: { viewModel.gitSyncAlert },
            set: { newValue in
                if let newValue {
                    viewModel.gitSyncAlert = newValue
                } else {
                    viewModel.dismissGitSyncAlert()
                }
            }
        )
    }

    private var checkedOutElsewhereAlertIsPresented: Binding<Bool> {
        Binding(
            get: { checkedOutElsewhereAlert != nil },
            set: { isPresented in
                if !isPresented {
                    checkedOutElsewhereAlert = nil
                }
            }
        )
    }

    private var assistantRevertSheetPresentedBinding: Binding<Bool> {
        Binding(
            get: { assistantRevertSheetState != nil },
            set: { isPresented in
                if !isPresented {
                    assistantRevertSheetState = nil
                }
            }
        )
    }

    private func handleSend() {
        isInputFocused = false
        viewModel.clearComposerAutocomplete()
        viewModel.sendTurn(codex: codex, threadID: thread.id)
    }

    @ViewBuilder
    private func composerStructuredPromptReplacement(message: CodexMessage) -> some View {
        if let request = message.structuredUserInputRequest {
            let isDismissed = viewModel.isStructuredPlanPromptDismissed(request.requestID, codex: codex)
            let isDismissing = viewModel.isStructuredPlanPromptDismissing(request.requestID, codex: codex)

            if !isDismissed {
                StructuredUserInputCard(
                    request: request,
                    isInteractionLocked: isDismissing,
                    secondaryActionTitle: isDismissing ? "Closing..." : "ESC",
                    onSecondaryAction: isDismissing ? nil : {
                        isInputFocused = true
                        viewModel.dismissStructuredPlanPrompt(message, codex: codex, threadID: thread.id)
                    }
                )
                .id(request.requestID)
                .padding(.horizontal, 12)
                .padding(.top, 4)
            } else {
                composerWithSubagentAccessory(
                    currentThread: currentResolvedThread,
                    activeTurnID: codex.activeTurnID(for: thread.id),
                    isThreadRunning: codex.timelineState(for: thread.id).renderSnapshot.isThreadRunning,
                    isEmptyThread: codex.timelineState(for: thread.id).renderSnapshot.messages.isEmpty,
                    isWorktreeProject: currentResolvedThread.isManagedWorktreeProject,
                    showsGitControls: codex.isConnected && currentResolvedThread.gitWorkingDirectory != nil,
                    gitWorkingDirectory: currentResolvedThread.gitWorkingDirectory
                )
            }
        } else {
            composerWithSubagentAccessory(
                currentThread: currentResolvedThread,
                activeTurnID: codex.activeTurnID(for: thread.id),
                isThreadRunning: codex.timelineState(for: thread.id).renderSnapshot.isThreadRunning,
                isEmptyThread: codex.timelineState(for: thread.id).renderSnapshot.messages.isEmpty,
                isWorktreeProject: currentResolvedThread.isManagedWorktreeProject,
                showsGitControls: codex.isConnected && currentResolvedThread.gitWorkingDirectory != nil,
                gitWorkingDirectory: currentResolvedThread.gitWorkingDirectory
            )
        }
    }

    private func handleGitActionSelection(
        _ action: TurnGitActionKind,
        isThreadRunning: Bool,
        gitWorkingDirectory: String?
    ) {
        guard canRunGitAction(isThreadRunning: isThreadRunning, gitWorkingDirectory: gitWorkingDirectory) else { return }
        viewModel.triggerGitAction(
            action,
            codex: codex,
            workingDirectory: gitWorkingDirectory,
            threadID: thread.id,
            activeTurnID: codex.activeTurnID(for: thread.id)
        )
    }

    private func canRunGitAction(isThreadRunning: Bool, gitWorkingDirectory: String?) -> Bool {
        viewModel.canRunGitAction(
            isConnected: codex.isConnected,
            isThreadRunning: isThreadRunning,
            hasGitWorkingDirectory: gitWorkingDirectory != nil
        )
    }

    // Re-resolves the active thread so handoff/reconnect UI always uses the freshest cwd + title.
    private var currentResolvedThread: CodexThread {
        codex.thread(for: thread.id) ?? thread
    }

    // Reuses the same running-thread gate as Stop/Git actions so worktree handoff never races a live run.
    private func isWorktreeHandoffAvailable(
        isThreadRunning: Bool,
        gitWorkingDirectory: String?
    ) -> Bool {
        canRunGitAction(
            isThreadRunning: isThreadRunning,
            gitWorkingDirectory: gitWorkingDirectory
        )
    }

    // Centralizes the toolbar/composer availability rule so both entry points stay aligned.
    private func canHandOffToWorktree(
        isThreadRunning: Bool,
        gitWorkingDirectory: String?
    ) -> Bool {
        isWorktreeHandoffAvailable(
            isThreadRunning: isThreadRunning,
            gitWorkingDirectory: gitWorkingDirectory
        ) && !viewModel.isCreatingGitWorktree
    }

    private func handleWorktreeHandoffTap(currentThread: CodexThread) {
        if currentThread.isManagedWorktreeProject {
            Task { @MainActor in
                do {
                    let move = try await WorktreeFlowCoordinator.handoffThreadToLocal(
                        thread: currentThread,
                        codex: codex
                    )
                    viewModel.refreshGitBranchTargets(
                        codex: codex,
                        workingDirectory: move.projectPath,
                        threadID: thread.id
                    )
                } catch {
                    viewModel.gitSyncAlert = TurnGitSyncAlert(
                        title: "Local Handoff Failed",
                        message: error.localizedDescription.isEmpty
                            ? "Could not hand off the thread back to Local."
                            : error.localizedDescription,
                        action: .dismissOnly
                    )
                }
            }
            return
        }

        guard let associatedWorktreePath = codex.associatedManagedWorktreePath(for: thread.id) else {
            isShowingWorktreeHandoff = true
            return
        }

        Task { @MainActor in
            viewModel.isCreatingGitWorktree = true
            defer { viewModel.isCreatingGitWorktree = false }

            do {
                let outcome = try await WorktreeFlowCoordinator.handoffThreadToWorktree(
                    threadID: thread.id,
                    sourceProjectPath: currentThread.gitWorkingDirectory,
                    associatedWorktreePath: associatedWorktreePath,
                    codex: codex
                )

                switch outcome {
                case .moved(let move):
                    viewModel.refreshGitBranchTargets(
                        codex: codex,
                        workingDirectory: move.projectPath,
                        threadID: thread.id
                    )
                case .missingAssociatedWorktree:
                    isShowingWorktreeHandoff = true
                }
            } catch {
                viewModel.gitSyncAlert = TurnGitSyncAlert(
                    title: "Worktree Handoff Failed",
                    message: error.localizedDescription.isEmpty
                        ? "Could not hand off the thread to the new worktree."
                        : error.localizedDescription,
                    action: .dismissOnly
                )
            }
        }
    }

    private func handleInitialAppear(activeTurnID: String?) {
        syncApprovalAlertPresentation()
        if let pendingComposerAction = codex.consumePendingComposerAction(for: thread.id) {
            viewModel.applyPendingComposerAction(pendingComposerAction)
            isInputFocused = true
        }
    }

    private func handlePhotoPickerItemsChanged(_ newItems: [PhotosPickerItem]) {
        viewModel.enqueuePhotoPickerItems(newItems, codex: codex)
        viewModel.photoPickerItems = []
    }

    private func startAssistantRevertPreview(message: CodexMessage, gitWorkingDirectory: String?) {
        guard let gitWorkingDirectory,
              let changeSet = codex.readyChangeSet(forAssistantMessage: message),
              let presentation = codex.assistantRevertPresentation(
                for: message,
                workingDirectory: gitWorkingDirectory
              ),
              presentation.isEnabled else {
            return
        }

        assistantRevertSheetState = AssistantRevertSheetState(
            changeSet: changeSet,
            presentation: presentation,
            preview: nil,
            isLoadingPreview: true,
            isApplying: false,
            errorMessage: nil
        )

        Task { @MainActor in
            do {
                let preview = try await codex.previewRevert(
                    changeSet: changeSet,
                    workingDirectory: gitWorkingDirectory
                )
                guard assistantRevertSheetState?.id == changeSet.id else { return }
                assistantRevertSheetState?.preview = preview
                assistantRevertSheetState?.isLoadingPreview = false
            } catch {
                guard assistantRevertSheetState?.id == changeSet.id else { return }
                assistantRevertSheetState?.isLoadingPreview = false
                assistantRevertSheetState?.errorMessage = error.localizedDescription
            }
        }
    }

    private func confirmAssistantRevert(gitWorkingDirectory: String?) {
        guard let gitWorkingDirectory,
              var assistantRevertSheetState,
              let preview = assistantRevertSheetState.preview,
              preview.canRevert else {
            return
        }

        assistantRevertSheetState.isApplying = true
        assistantRevertSheetState.errorMessage = nil
        self.assistantRevertSheetState = assistantRevertSheetState

        let changeSet = assistantRevertSheetState.changeSet
        Task { @MainActor in
            do {
                let applyResult = try await codex.applyRevert(
                    changeSet: changeSet,
                    workingDirectory: gitWorkingDirectory
                )

                guard self.assistantRevertSheetState?.id == changeSet.id else { return }
                if applyResult.success {
                    if let status = applyResult.status {
                        viewModel.gitRepoSync = status
                    } else {
                        viewModel.scheduleGitStatusRefresh(
                            codex: codex,
                            workingDirectory: gitWorkingDirectory,
                            threadID: thread.id
                        )
                    }
                    self.assistantRevertSheetState = nil
                    return
                }

                self.assistantRevertSheetState?.isApplying = false
                let affectedFiles = self.assistantRevertSheetState?.preview?.affectedFiles
                    ?? changeSet.fileChanges.map(\.path)
                self.assistantRevertSheetState?.preview = RevertPreviewResult(
                    canRevert: false,
                    affectedFiles: affectedFiles,
                    conflicts: applyResult.conflicts,
                    unsupportedReasons: applyResult.unsupportedReasons,
                    stagedFiles: applyResult.stagedFiles
                )
                self.assistantRevertSheetState?.errorMessage = applyResult.conflicts.first?.message
                    ?? applyResult.unsupportedReasons.first
            } catch {
                guard self.assistantRevertSheetState?.id == changeSet.id else { return }
                self.assistantRevertSheetState?.isApplying = false
                self.assistantRevertSheetState?.errorMessage = error.localizedDescription
            }
        }
    }

    private func prepareThreadIfReady(gitWorkingDirectory: String?) async {
        let didPrepare = await codex.prepareThreadForDisplay(threadId: thread.id)
        guard didPrepare, !Task.isCancelled, codex.activeThreadId == thread.id else { return }
        await codex.refreshContextWindowUsage(threadId: thread.id)
        guard !Task.isCancelled, codex.activeThreadId == thread.id else { return }
        viewModel.flushQueueIfPossible(codex: codex, threadID: thread.id)
        guard !Task.isCancelled, codex.activeThreadId == thread.id else { return }
        guard gitWorkingDirectory != nil else { return }
        viewModel.refreshGitBranchTargets(
            codex: codex,
            workingDirectory: gitWorkingDirectory,
            threadID: thread.id
        )
    }

    // Shares the same default base branch between the toolbar overlay and the empty-thread Local menu.
    private var preferredWorktreeBaseBranch: String {
        let currentBranch = viewModel.currentGitBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        if !currentBranch.isEmpty {
            return currentBranch
        }

        let selectedBaseBranch = viewModel.selectedGitBaseBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        if !selectedBaseBranch.isEmpty {
            return selectedBaseBranch
        }
        return viewModel.gitDefaultBranch
    }

    // Creates a named worktree, then rebinds this same chat to that checkout.
    private func submitWorktreeHandoff(
        branchName: String,
        baseBranch: String,
        gitWorkingDirectory: String?,
        activeTurnID: String?
    ) {
        viewModel.requestCreateGitWorktree(
            named: branchName,
            fromBaseBranch: baseBranch,
            changeTransfer: .none,
            codex: codex,
            workingDirectory: gitWorkingDirectory,
            threadID: thread.id,
            activeTurnID: activeTurnID,
            onOpenWorktree: { result in
                guard !result.alreadyExisted else {
                    viewModel.gitSyncAlert = TurnGitSyncAlert(
                        title: "Branch Already Exists",
                        message: "A worktree for '\(result.branch)' already exists. Choose a different name.",
                        action: .dismissOnly
                    )
                    return
                }

                Task { @MainActor in
                    do {
                        let outcome = try await WorktreeFlowCoordinator.handoffThreadToWorktree(
                            threadID: thread.id,
                            sourceProjectPath: gitWorkingDirectory,
                            associatedWorktreePath: result.worktreePath,
                            codex: codex
                        )

                        if case .moved(let move) = outcome {
                            isShowingWorktreeHandoff = false
                            viewModel.refreshGitBranchTargets(
                                codex: codex,
                                workingDirectory: move.projectPath,
                                threadID: thread.id
                            )
                        }
                    } catch {
                        viewModel.gitSyncAlert = TurnGitSyncAlert(
                            title: "Worktree Handoff Failed",
                            message: error.localizedDescription.isEmpty
                                ? "Could not hand off the thread to the new worktree."
                                : error.localizedDescription,
                            action: .dismissOnly
                        )
                    }
                }
            }
        )
    }

    // Forks the current conversation into the Local checkout when possible.
    private func startLocalFork() {
        Task { @MainActor in
            guard !isForkingThread else { return }
            let sourceThread = currentResolvedThread
            guard WorktreeFlowCoordinator.localForkProjectPath(
                for: sourceThread,
                localCheckoutPath: viewModel.gitLocalCheckoutPath
            ) != nil else {
                viewModel.gitSyncAlert = TurnGitSyncAlert(
                    title: "Local Fork Unavailable",
                    message: sourceThread.isManagedWorktreeProject
                        ? "Could not resolve the Local checkout for this worktree thread."
                        : "Could not resolve the local project path for this thread.",
                    action: .dismissOnly
                )
                return
            }
            isForkingThread = true
            defer { isForkingThread = false }

            do {
                let forkedThread = try await WorktreeFlowCoordinator.forkThreadToLocal(
                    sourceThread: sourceThread,
                    localCheckoutPath: viewModel.gitLocalCheckoutPath,
                    codex: codex
                )
                openThread(forkedThread.id)
            } catch {
                if codex.lastErrorMessage?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                    codex.lastErrorMessage = error.localizedDescription
                }
            }
        }
    }

    // Creates a named worktree, then forks the conversation into that checkout.
    private func submitForkIntoNewWorktree(
        branchName: String,
        baseBranch: String,
        gitWorkingDirectory: String?,
        activeTurnID: String?
    ) {
        viewModel.requestCreateGitWorktree(
            named: branchName,
            fromBaseBranch: baseBranch,
            changeTransfer: .none,
            codex: codex,
            workingDirectory: gitWorkingDirectory,
            threadID: thread.id,
            activeTurnID: activeTurnID,
            onOpenWorktree: { result in
                guard !result.alreadyExisted else {
                    viewModel.gitSyncAlert = TurnGitSyncAlert(
                        title: "Branch Already Exists",
                        message: "A worktree for '\(result.branch)' already exists. Choose a different name.",
                        action: .dismissOnly
                    )
                    return
                }

                isForkingThread = true
                Task { @MainActor in
                    defer { isForkingThread = false }

                    do {
                        let forkedThread = try await codex.forkThreadIfReady(
                            from: thread.id,
                            target: .projectPath(result.worktreePath)
                        )
                        isShowingForkWorktree = false
                        openThread(forkedThread.id)
                    } catch {
                        viewModel.gitSyncAlert = TurnGitSyncAlert(
                            title: "Worktree Fork Failed",
                            message: error.localizedDescription.isEmpty
                                ? "Could not fork the thread into the new worktree."
                                : error.localizedDescription,
                            action: .dismissOnly
                        )
                    }
                }
            }
        )
    }

    // Re-resolves the thread at action time so follow-up chats inherit the freshest cwd after sync/reconnect.
    private func resolvedProjectPathForFollowUpThread() -> String? {
        let currentThread = codex.thread(for: thread.id) ?? thread
        return currentThread.normalizedProjectPath
    }

    // Creates a fresh thread in the same project and opens it straight into the review flow.
    private func startCodeReviewThread(target: TurnComposerReviewTarget) {
        Task { @MainActor in
            do {
                _ = try await codex.startThreadIfReady(
                    preferredProjectPath: resolvedProjectPathForFollowUpThread(),
                    pendingComposerAction: .codeReview(target: pendingCodeReviewTarget(for: target))
                )
                viewModel.clearComposerReviewSelection()
            } catch {
                if codex.lastErrorMessage?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                    codex.lastErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func pendingCodeReviewTarget(
        for target: TurnComposerReviewTarget
    ) -> CodexPendingCodeReviewTarget {
        switch target {
        case .uncommittedChanges:
            return .uncommittedChanges
        case .baseBranch:
            return .baseBranch
        }
    }

    private var isPhotoPickerPresentedBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isPhotoPickerPresented },
            set: { viewModel.isPhotoPickerPresented = $0 }
        )
    }

    private var isCameraPresentedBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isCameraPresented },
            set: { viewModel.isCameraPresented = $0 }
        )
    }

    private var photoPickerItemsBinding: Binding<[PhotosPickerItem]> {
        Binding(
            get: { viewModel.photoPickerItems },
            set: { viewModel.photoPickerItems = $0 }
        )
    }

    // MARK: - Derived UI state

    private var orderedModelOptions: [CodexModelOption] {
        TurnComposerMetaMapper.orderedModels(from: codex.availableModels)
    }

    private var reasoningDisplayOptions: [TurnComposerReasoningDisplayOption] {
        TurnComposerMetaMapper.reasoningDisplayOptions(
            from: codex.supportedReasoningEffortsForSelectedModel().map(\.reasoningEffort)
        )
    }

    private var selectedModelTitle: String {
        guard let selectedModel = codex.selectedModelOption() else {
            return "Select model"
        }

        return TurnComposerMetaMapper.modelTitle(for: selectedModel)
    }

    private var approvalForThread: CodexApprovalRequest? {
        codex.pendingApproval(for: thread.id)
    }

    private var approvalRequestChangeToken: String? {
        guard let request = approvalForThread else {
            return nil
        }

        let reason = request.reason?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let command = request.command?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return [request.id, reason, command].joined(separator: "|")
    }

    private func syncApprovalAlertPresentation() {
        alertApprovalRequest = approvalForThread
        isApprovalAlertPresented = alertApprovalRequest != nil
    }

    private func restoreApprovalAlert(afterFailureOf request: CodexApprovalRequest) {
        alertApprovalRequest = approvalForThread ?? request
        isApprovalAlertPresented = alertApprovalRequest != nil
    }

    private var parentThread: CodexThread? {
        guard let parentThreadId = thread.parentThreadId else {
            return nil
        }

        return codex.thread(for: parentThreadId)
    }

    private func showThreadPathPreview() {
        guard threadNavigationContext(for: currentResolvedThread) != nil else {
            return
        }

        threadPathPreviewDismissTask?.cancel()
        withAnimation(.easeInOut(duration: 0.16)) {
            isShowingThreadPathPreview = true
        }

        threadPathPreviewDismissTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isShowingThreadPathPreview = false
                }
            }
        }
    }

    private func threadNavigationContext(for thread: CodexThread) -> TurnThreadNavigationContext? {
        guard let path = thread.gitWorkingDirectory,
              !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let fullPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let folderName = (fullPath as NSString).lastPathComponent
        return TurnThreadNavigationContext(
            folderName: folderName.isEmpty ? fullPath : folderName,
            subtitle: fullPath,
            fullPath: fullPath
        )
    }

    @ViewBuilder
    private func composerWithSubagentAccessory(
        currentThread: CodexThread,
        activeTurnID: String?,
        isThreadRunning: Bool,
        isEmptyThread: Bool,
        isWorktreeProject: Bool,
        showsGitControls: Bool,
        gitWorkingDirectory: String?
    ) -> some View {
        VStack(spacing: 8) {
            if let parentThread = parentThread {
                SubagentParentAccessoryCard(
                    parentTitle: parentThread.displayTitle,
                    agentLabel: codex.resolvedSubagentDisplayLabel(threadId: thread.id, agentId: thread.agentId)
                        ?? "Subagent",
                    onTap: { openThread(parentThread.id) }
                )
                .padding(.horizontal, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if isForkingThread {
                forkLoadingNotice
                    .padding(.horizontal, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            TurnComposerHostView(
                viewModel: viewModel,
                codex: codex,
                thread: currentThread,
                activeTurnID: activeTurnID,
                isThreadRunning: isThreadRunning,
                isEmptyThread: isEmptyThread,
                isWorktreeProject: isWorktreeProject,
                canForkLocally: WorktreeFlowCoordinator.localForkProjectPath(
                    for: currentThread,
                    localCheckoutPath: viewModel.gitLocalCheckoutPath
                ) != nil,
                isInputFocused: $isInputFocused,
                orderedModelOptions: orderedModelOptions,
                selectedModelTitle: selectedModelTitle,
                reasoningDisplayOptions: reasoningDisplayOptions,
                showsGitControls: showsGitControls,
                isGitBranchSelectorEnabled: canRunGitAction(
                    isThreadRunning: isThreadRunning,
                    gitWorkingDirectory: gitWorkingDirectory
                ),
                onSelectGitBranch: { branch in
                    guard canRunGitAction(
                        isThreadRunning: isThreadRunning,
                        gitWorkingDirectory: gitWorkingDirectory
                    ) else { return }

                    if let worktreePath = viewModel.worktreePathForCheckedOutElsewhereBranch(branch) {
                        if let normalizedWorktreePath = CodexThreadStartProjectBinding.normalizedProjectPath(worktreePath) {
                            let resolvedWorktreePath = TurnWorktreeRouting.canonicalProjectPath(normalizedWorktreePath)
                                ?? normalizedWorktreePath
                            if TurnWorktreeRouting.comparableProjectPath(currentThread.normalizedProjectPath) == resolvedWorktreePath {
                                return
                            }
                        }

                        let existingThread = WorktreeFlowCoordinator.liveThreadForCheckedOutElsewhereBranch(
                            projectPath: worktreePath,
                            codex: codex,
                            currentThread: currentThread
                        )
                        checkedOutElsewhereAlert = CheckedOutElsewhereAlert(
                            branch: branch,
                            threadID: existingThread?.id
                        )
                        return
                    }

                    viewModel.requestSwitchGitBranch(
                        to: branch,
                        codex: codex,
                        workingDirectory: gitWorkingDirectory,
                        threadID: thread.id,
                        activeTurnID: activeTurnID
                    )
                },
                onCreateGitBranch: { branchName in
                    guard canRunGitAction(
                        isThreadRunning: isThreadRunning,
                        gitWorkingDirectory: gitWorkingDirectory
                    ) else { return }

                    viewModel.requestCreateGitBranch(
                        named: branchName,
                        codex: codex,
                        workingDirectory: gitWorkingDirectory,
                        threadID: thread.id,
                        activeTurnID: activeTurnID
                    )
                },
                onRefreshGitBranches: {
                    guard showsGitControls else { return }
                    viewModel.refreshGitBranchTargets(
                        codex: codex,
                        workingDirectory: gitWorkingDirectory,
                        threadID: thread.id
                    )
                },
                onStartCodeReviewThread: startCodeReviewThread,
                onStartForkThreadLocally: startLocalFork,
                onOpenForkWorktree: {
                    isShowingForkWorktree = true
                },
                onOpenWorktreeHandoff: {
                    handleWorktreeHandoffTap(currentThread: currentThread)
                },
                onOpenFeedbackMail: {
                    openURL(AppEnvironment.feedbackMailtoURL)
                },
                onShowStatus: presentStatusSheet,
                voiceButtonPresentation: voiceButtonPresentation,
                isVoiceRecording: isVoiceRecording,
                voiceAudioLevels: voiceTranscriptionManager.audioLevels,
                voiceRecordingDuration: voiceTranscriptionManager.recordingDuration,
                onTapVoice: handleVoiceButtonTap,
                onCancelVoiceRecording: cancelVoiceRecordingIfNeeded,
                onSend: handleSend
            )
        }
    }

    // Mirrors the mic CTA state so the composer can swap between ready, record, and stop.
    private var voiceButtonPresentation: TurnComposerVoiceButtonPresentation {
        if isVoiceTranscribing {
            return TurnComposerVoiceButtonPresentation(
                systemImageName: "waveform",
                foregroundColor: Color(.secondaryLabel),
                backgroundColor: Color(.systemGray5),
                accessibilityLabel: "Transcribing voice note",
                isDisabled: true,
                showsProgress: true,
                hasCircleBackground: true
            )
        }

        if isVoicePreflighting {
            return TurnComposerVoiceButtonPresentation(
                systemImageName: "hourglass",
                foregroundColor: Color(.secondaryLabel),
                backgroundColor: Color(.systemGray5),
                accessibilityLabel: "Preparing microphone",
                isDisabled: true,
                showsProgress: true,
                hasCircleBackground: true
            )
        }

        if isVoiceRecording {
            return TurnComposerVoiceButtonPresentation(
                systemImageName: "stop.fill",
                foregroundColor: Color(.systemBackground),
                backgroundColor: Color(.systemRed),
                accessibilityLabel: "Stop voice recording",
                isDisabled: false,
                showsProgress: false,
                hasCircleBackground: true
            )
        }

        return TurnComposerVoiceButtonPresentation(
            systemImageName: "mic",
            foregroundColor: Color(.secondaryLabel),
            backgroundColor: .clear,
            accessibilityLabel: "Start voice transcription",
            isDisabled: !codex.isConnected,
            showsProgress: false,
            hasCircleBackground: false
        )
    }

    // Switches the mic button between login, recording, and transcription states.
    private func handleVoiceButtonTap() {
        if isVoiceTranscribing {
            return
        }

        if isVoiceRecording {
            Task { @MainActor in
                await stopVoiceTranscription()
            }
            return
        }

        Task { @MainActor in
            await startVoiceRecordingIfReady()
        }
    }

    // Stops the recorder, transcribes through the bridge, and appends the final text into the draft.
    private func stopVoiceTranscription() async {
        hasTriggeredVoiceAutoStop = false
        isVoiceTranscribing = true
        defer { isVoiceTranscribing = false }

        do {
            guard let clip = try voiceTranscriptionManager.stopRecording() else {
                isVoiceRecording = false
                voiceTranscriptionManager.resetMeteringState()
                return
            }

            defer {
                try? FileManager.default.removeItem(at: clip.url)
            }

            isVoiceRecording = false
            voiceTranscriptionManager.resetMeteringState()
            let transcript = try await codex.transcribeVoiceAudioFile(
                at: clip.url,
                durationSeconds: clip.durationSeconds
            )
            clearVoiceRecovery()
            viewModel.appendVoiceTranscript(transcript)
            // Keep voice flows keyboard-free; users can tap into the draft afterward if they want to edit.
            isInputFocused = false
        } catch {
            isVoiceRecording = false
            voiceTranscriptionManager.resetMeteringState()
            presentVoiceRecovery(for: error)
        }
    }

    // Starts microphone capture directly; auth is resolved when the user stops recording, matching Litter's flow.
    @MainActor
    private func startVoiceRecordingIfReady() async {
        guard !isVoicePreflighting else {
            return
        }

        guard codex.supportsBridgeVoiceAuth else {
            presentVoiceRecovery(for: .bridgeSessionUnsupported)
            return
        }

        guard codex.isConnected else {
            presentVoiceRecovery(for: .reconnectRequired)
            return
        }

        clearVoiceRecovery()
        codex.lastErrorMessage = nil
        hasTriggeredVoiceAutoStop = false
        // Dismiss any active text focus before recording so the keyboard does not
        // compete with the waveform UI or waste vertical space during capture.
        isInputFocused = false
        let preflightGeneration = voicePreflightGeneration + 1
        voicePreflightGeneration = preflightGeneration
        isVoicePreflighting = true
        defer {
            if isVoicePreflightCurrent(preflightGeneration) {
                isVoicePreflighting = false
            }
        }

        do {
            guard isVoicePreflightCurrent(preflightGeneration), codex.isConnected else {
                return
            }
            try await voiceTranscriptionManager.startRecording()
            guard isVoicePreflightCurrent(preflightGeneration), codex.isConnected else {
                voiceTranscriptionManager.cancelRecording()
                return
            }
            isVoiceRecording = true
            isInputFocused = false
        } catch {
            presentVoiceRecovery(for: error)
        }
    }

    // Clears any partial microphone capture when the screen leaves the active voice flow.
    private func cancelVoiceRecordingIfNeeded() {
        guard isVoiceRecording else {
            return
        }

        voiceTranscriptionManager.cancelRecording()
        isVoiceRecording = false
        hasTriggeredVoiceAutoStop = false
    }

    // Trigger a hair before the hard validation limit so the saved WAV never misses by timer drift.
    private var voiceAutoStopThreshold: TimeInterval {
        max(0, CodexVoiceTranscriptionPreflight.maxDurationSeconds - 0.25)
    }

    private func clearVoiceRecovery() {
        voiceRecoveryReason = nil
    }

    // Keeps voice failures out of the transcript by routing them into a dedicated recovery accessory.
    private func presentVoiceRecovery(for error: Error) {
        presentVoiceRecovery(for: codex.classifyVoiceFailure(error))
    }

    private func presentVoiceRecovery(for reason: CodexVoiceFailureReason) {
        voiceRecoveryReason = reason
        codex.lastErrorMessage = nil
    }

    private func buildVoiceRecoveryPresentation(for reason: CodexVoiceFailureReason) -> VoiceRecoveryPresentation {
        switch reason {
        case .reconnectRequired:
            return VoiceRecoveryPresentation(
                snapshot: ConnectionRecoverySnapshot(
                    title: "Voice Mode",
                    summary: "Reconnect to your Mac to use voice mode.",
                    detail: "Keep the bridge running on your Mac, then try the microphone again.",
                    status: .interrupted,
                    trailingStyle: .action("Reconnect")
                ),
                action: .reconnect
            )
        case .bridgeSessionUnsupported:
            return VoiceRecoveryPresentation(
                snapshot: ConnectionRecoverySnapshot(
                    title: "Voice Mode",
                    summary: "This bridge session does not support voice mode yet.",
                    detail: "Restart the bridge on your Mac, then reconnect this iPhone. If it still happens, update the bridge on your Mac and pair again.",
                    status: .actionRequired,
                    trailingStyle: .action("Reconnect")
                ),
                action: .reconnect
            )
        case .macLoginRequired:
            return VoiceRecoveryPresentation(
                snapshot: ConnectionRecoverySnapshot(
                    title: "Voice Mode",
                    summary: "Sign in to ChatGPT on your Mac to use voice mode.",
                    detail: "Open ChatGPT on the paired Mac, sign in there, then come back here and try again.",
                    status: .actionRequired,
                    trailingStyle: .action("How To Fix")
                ),
                action: .showSetupHelp
            )
        case .macReauthenticationRequired:
            return VoiceRecoveryPresentation(
                snapshot: ConnectionRecoverySnapshot(
                    title: "Voice Mode",
                    summary: "ChatGPT voice needs a fresh sign-in on your Mac.",
                    detail: "Open ChatGPT on the paired Mac, sign in again there, then retry voice mode here.",
                    status: .actionRequired,
                    trailingStyle: .action("How To Fix")
                ),
                action: .showSetupHelp
            )
        case .voiceSyncInProgress:
            return VoiceRecoveryPresentation(
                snapshot: ConnectionRecoverySnapshot(
                    title: "Voice Mode",
                    summary: "Voice mode is still syncing from your Mac.",
                    detail: "Keep the bridge connected for a moment, then try again.",
                    status: .syncing,
                    trailingStyle: .progress
                ),
                action: .none
            )
        case .chatGPTRequired:
            return VoiceRecoveryPresentation(
                snapshot: ConnectionRecoverySnapshot(
                    title: "Voice Mode",
                    summary: "Voice mode needs a ChatGPT session on your Mac.",
                    detail: "API-key-only auth is not enough here. Sign in to ChatGPT on the paired Mac, then try again.",
                    status: .actionRequired,
                    trailingStyle: .action("How To Fix")
                ),
                action: .showSetupHelp
            )
        case .microphonePermissionRequired:
            return VoiceRecoveryPresentation(
                snapshot: ConnectionRecoverySnapshot(
                    title: "Voice Mode",
                    summary: "Microphone access is off for Harmony.",
                    detail: "Open iPhone Settings, allow Microphone for Harmony, then try recording again.",
                    status: .actionRequired,
                    trailingStyle: .action("Open Settings")
                ),
                action: .openSystemSettings
            )
        case .microphoneUnavailable:
            return VoiceRecoveryPresentation(
                snapshot: ConnectionRecoverySnapshot(
                    title: "Voice Mode",
                    summary: "No microphone input is available right now.",
                    detail: "Check that another app is not holding the microphone, then try again.",
                    status: .actionRequired,
                    trailingStyle: .none
                ),
                action: .none
            )
        case .recorderUnavailable:
            return VoiceRecoveryPresentation(
                snapshot: ConnectionRecoverySnapshot(
                    title: "Voice Mode",
                    summary: "Harmony could not start the recorder.",
                    detail: "Close other audio-heavy apps, then try voice mode again.",
                    status: .actionRequired,
                    trailingStyle: .none
                ),
                action: .none
            )
        case .generic(let message):
            return VoiceRecoveryPresentation(
                snapshot: ConnectionRecoverySnapshot(
                    title: "Voice Mode",
                    summary: message,
                    status: .actionRequired,
                    trailingStyle: .none
                ),
                action: .none
            )
        }
    }

    private func handleVoiceRecoveryAction(_ action: VoiceRecoveryAction) {
        switch action {
        case .reconnect:
            reconnectAction?()
        case .showSetupHelp:
            isShowingVoiceSetupSheet = true
        case .openSystemSettings:
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
                return
            }
            openURL(settingsURL)
        case .none:
            break
        }
    }

    private func handleConnectionRecoveryAction() {
        if shouldOfferWakeSavedMacDisplayAction {
            wakeMacDisplayAction?()
            return
        }

        reconnectAction?()
    }

    // Invalidates any in-flight async mic startup so it cannot reopen the recorder after leaving the screen.
    private func invalidatePendingVoicePreflight() {
        voicePreflightGeneration += 1
        isVoicePreflighting = false
    }

    private func isVoicePreflightCurrent(_ generation: Int) -> Bool {
        generation == voicePreflightGeneration
    }

    private var forkLoadingNotice: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)

            VStack(alignment: .leading, spacing: 2) {
                Text("Creating fork...")
                    .font(AppFont.subheadline(weight: .semibold))
                Text("Opening the new chat")
                    .font(AppFont.caption())
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .adaptiveGlass(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func openThread(_ threadId: String) {
        codex.activeThreadId = threadId
        codex.markThreadAsViewed(threadId)
        codex.requestImmediateActiveThreadSync(threadId: threadId)
    }

    // MARK: - Empty State

    private var loadingState: some View {
        chatPlaceholderState(
            title: "Loading chat...",
            subtitle: "Fetching the latest messages for this conversation."
        )
    }

    private func resolvedEmptyState(for phase: CodexService.ThreadDisplayPhase) -> AnyView {
        switch phase {
        case .loading:
            return AnyView(loadingState)
        case .empty, .ready:
            return AnyView(emptyState)
        }
    }

    private var emptyState: some View {
        chatPlaceholderState(
            title: "Hi! How can I help you?",
            subtitle: "Chats are End-to-end encrypted"
        )
    }

    private func chatPlaceholderState(title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Text("Harmony")
                .font(AppFont.title2(weight: .semibold))
            Text(title)
                .font(AppFont.title2(weight: .semibold))
            Text(subtitle)
                .font(AppFont.caption())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private enum VoiceRecoveryAction: Equatable {
    case reconnect
    case showSetupHelp
    case openSystemSettings
    case none
}

private struct VoiceRecoveryPresentation: Equatable {
    let snapshot: ConnectionRecoverySnapshot
    let action: VoiceRecoveryAction
}

private struct ExternalBrowserPresentation: Identifiable, Equatable {
    let url: URL

    var id: String {
        url.absoluteString
    }
}

private enum ExternalBrowserLinkRouter {
    static func shouldPresentInAppBrowser(for url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host?.lowercased(),
              !host.isEmpty else {
            return false
        }

        return !isLocalHost(host)
    }

    private static func isLocalHost(_ host: String) -> Bool {
        if host == "localhost" || host == "127.0.0.1" || host == "::1" {
            return true
        }

        if host.hasSuffix(".local") {
            return true
        }

        let octets = host.split(separator: ".")
        if octets.count == 4,
           let first = Int(octets[0]),
           let second = Int(octets[1]) {
            if first == 10 || first == 127 {
                return true
            }

            if first == 192 && second == 168 {
                return true
            }

            if first == 172 && (16...31).contains(second) {
                return true
            }
        }

        return false
    }
}

private struct TurnExternalBrowserSheet: View {
    let url: URL

    @Environment(\.dismiss) private var dismiss
    @State private var pageState = BrowserPageState()
    @State private var browserController = BrowserWebViewController()

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    browserChrome(topInset: geometry.safeAreaInsets.top)

                    BrowserWebView(
                        url: url,
                        controller: browserController,
                        pageState: $pageState
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white)
                }
                .ignoresSafeArea(edges: [.top, .bottom])
            }
        }
        .onAppear {
            browserController.loadIfNeeded(url)
        }
    }

    private func browserChrome(topInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: topInset)

            HStack(spacing: 12) {
                browserIconButton(
                    systemName: "chevron.backward",
                    accessibilityLabel: pageState.canGoBack ? "Go back" : "Close browser"
                ) {
                    if pageState.canGoBack {
                        browserController.goBack()
                    } else {
                        dismiss()
                    }
                }

                Text(browserLocationText)
                    .font(AppFont.caption(weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    )

                browserIconButton(
                    systemName: "safari",
                    accessibilityLabel: "Open in Safari"
                ) {
                    UIApplication.shared.open(pageState.currentURL ?? url)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .padding(.bottom, 8)

            if pageState.isLoading {
                ProgressView(value: pageState.estimatedProgress)
                    .progressViewStyle(.linear)
                    .tint(.white.opacity(0.9))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
            }
        }
        .background(Color.black)
    }

    private var browserLocationText: String {
        Self.formatBrowserLocation(pageState.currentURL ?? url)
    }

    private static func formatBrowserLocation(_ url: URL) -> String {
        guard let host = url.host, !host.isEmpty else {
            return url.absoluteString
        }

        let normalizedHost = host.replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)
        let path = url.path == "/" ? "" : url.path
        let query = (url.query?.isEmpty == false) ? "?\(url.query!)" : ""
        return "\(normalizedHost)\(path)\(query)"
    }

    private func browserIconButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticFeedback.shared.triggerImpactFeedback(style: .light)
            action()
        } label: {
            Image(systemName: systemName)
                .font(AppFont.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .adaptiveGlass(.regular, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct BrowserPageState: Equatable {
    var estimatedProgress: Double = 0
    var isLoading = true
    var canGoBack = false
    var currentURL: URL?
}

private final class BrowserWebViewController {
    fileprivate let webView: WKWebView
    private var loadedURL: URL?

    init() {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.allowsInlineMediaPlayback = true
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        self.webView.scrollView.contentInsetAdjustmentBehavior = .never
        self.webView.allowsBackForwardNavigationGestures = true
        self.webView.backgroundColor = .white
        self.webView.isOpaque = false
    }

    func loadIfNeeded(_ url: URL) {
        guard loadedURL != url else { return }
        loadedURL = url
        webView.load(URLRequest(url: url))
    }

    func goBack() {
        guard webView.canGoBack else { return }
        webView.goBack()
    }
}

private struct BrowserWebView: UIViewRepresentable {
    let url: URL
    let controller: BrowserWebViewController
    @Binding var pageState: BrowserPageState

    func makeCoordinator() -> Coordinator {
        Coordinator(pageState: $pageState)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = controller.webView
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        context.coordinator.attach(to: webView)
        controller.loadIfNeeded(url)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.navigationDelegate !== context.coordinator {
            webView.navigationDelegate = context.coordinator
        }
        if webView.uiDelegate !== context.coordinator {
            webView.uiDelegate = context.coordinator
        }
        context.coordinator.attach(to: webView)
        controller.loadIfNeeded(url)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.detach(from: webView)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        @Binding private var pageState: BrowserPageState
        private weak var observedWebView: WKWebView?

        init(pageState: Binding<BrowserPageState>) {
            self._pageState = pageState
        }

        func attach(to webView: WKWebView) {
            guard observedWebView !== webView else { return }
            detachCurrentWebView()
            webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: [.new], context: nil)
            observedWebView = webView
            updateProgress(for: webView)
        }

        func detach(from webView: WKWebView) {
            guard observedWebView === webView else { return }
            detachCurrentWebView()
        }

        deinit {
            detachCurrentWebView()
        }

        override func observeValue(
            forKeyPath keyPath: String?,
            of object: Any?,
            change: [NSKeyValueChangeKey : Any]?,
            context: UnsafeMutableRawPointer?
        ) {
            guard keyPath == #keyPath(WKWebView.estimatedProgress),
                  let webView = object as? WKWebView else {
                return
            }

            updateProgress(for: webView)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            pageState.isLoading = true
            updateProgress(for: webView)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            updateProgress(for: webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            pageState.estimatedProgress = 1
            pageState.isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            pageState.isLoading = false
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            pageState.isLoading = false
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil, let targetURL = navigationAction.request.url {
                webView.load(URLRequest(url: targetURL))
            }
            return nil
        }

        private func detachCurrentWebView() {
            guard let observedWebView else { return }
            observedWebView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
            self.observedWebView = nil
        }

        private func updateProgress(for webView: WKWebView) {
            let progress = min(max(webView.estimatedProgress, 0), 1)
            pageState.estimatedProgress = progress
            pageState.isLoading = webView.isLoading || progress < 1
            pageState.canGoBack = webView.canGoBack
            pageState.currentURL = webView.url
        }
    }
}

private struct SubagentParentAccessoryCard: View {
    let parentTitle: String
    let agentLabel: String
    let onTap: () -> Void

    var body: some View {
        GlassAccessoryCard(onTap: onTap) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 22, height: 22)

                Image(systemName: "arrow.turn.up.left")
                    .font(AppFont.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
        } header: {
            HStack(alignment: .center, spacing: 6) {
                Text("Subagent")
                    .font(AppFont.mono(.caption2))
                    .foregroundStyle(.secondary)

                Circle()
                    .fill(Color(.separator).opacity(0.6))
                    .frame(width: 3, height: 3)

                SubagentLabelParser.styledText(for: agentLabel)
                    .font(AppFont.caption(weight: .regular))
                    .lineLimit(1)
            }
        } summary: {
            Text("Back to \(parentTitle)")
                .font(AppFont.subheadline(weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        } trailing: {
            Image(systemName: "chevron.right")
                .font(AppFont.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
    }
}

private struct CheckedOutElsewhereAlert: Identifiable {
    let id = UUID()
    let branch: String
    let threadID: String?

    var title: String {
        "Branch already open elsewhere"
    }

    var message: String {
        if threadID != nil {
            return "'\(branch)' is already checked out in another worktree. Open that chat to continue there."
        }

        return "'\(branch)' is already checked out in another worktree. Open that chat from the sidebar to continue there."
    }
}

private struct RuntimeDebugLogSheet: View {
    @Environment(CodexService.self) private var codex
    @Environment(\.dismiss) private var dismiss

    private var combinedLogText: String {
        codex.runtimeDebugLogEntries.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            Group {
                if codex.runtimeDebugLogEntries.isEmpty {
                    ContentUnavailableView(
                        "No Runtime Logs Yet",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Start a Plan Mode turn and the RPC events will appear here.")
                    )
                } else {
                    ScrollView {
                        Text(combinedLogText)
                            .font(AppFont.mono(.footnote))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle("Runtime Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Clear") {
                        codex.clearRuntimeDebugLog()
                    }

                    Button("Copy") {
                        UIPasteboard.general.string = combinedLogText
                    }
                    .disabled(combinedLogText.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TurnView(
            thread: CodexThread(id: "thread_preview", title: "Preview"),
            isWakingMacDisplayRecovery: false
        )
            .environment(CodexService())
    }
}
