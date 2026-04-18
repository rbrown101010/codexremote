// FILE: ComposerBottomBar.swift
// Purpose: Bottom bar with attachment/model/reasoning/access menus, queue controls, and send button.
// Layer: View Component
// Exports: ComposerBottomBar
// Depends on: SwiftUI, TurnComposerMetaMapper

import SwiftUI
import UIKit

struct ComposerBottomBar: View {
    @Environment(\.colorScheme) private var colorScheme

    // Data
    let orderedModelOptions: [CodexModelOption]
    let selectedModelID: String?
    let selectedModelTitle: String
    let isLoadingModels: Bool
    let runtimeState: TurnComposerRuntimeState
    let runtimeActions: TurnComposerRuntimeActions
    let remainingAttachmentSlots: Int
    let isComposerInteractionLocked: Bool
    let isSendDisabled: Bool
    let isPlanModeArmed: Bool
    let queuedCount: Int
    let isQueuePaused: Bool
    let activeTurnID: String?
    let isThreadRunning: Bool
    let isEmptyThread: Bool
    let isWorktreeProject: Bool
    let voiceButtonPresentation: TurnComposerVoiceButtonPresentation
    let selectedAccessMode: CodexAccessMode
    let contextWindowUsage: ContextWindowUsage?
    let rateLimitsErrorMessage: String?
    let showsGitBranchSelector: Bool
    let isGitBranchSelectorEnabled: Bool
    let availableGitBranchTargets: [String]
    let gitBranchesCheckedOutElsewhere: Set<String>
    let gitWorktreePathsByBranch: [String: String]
    let selectedGitBaseBranch: String
    let currentGitBranch: String
    let gitDefaultBranch: String
    let isLoadingGitBranchTargets: Bool
    let isSwitchingGitBranch: Bool
    let isCreatingGitWorktree: Bool
    let onTapAddImage: () -> Void
    let onTapTakePhoto: () -> Void
    let onTapVoice: () -> Void
    let onSelectGitBranch: (String) -> Void
    let onSelectGitBaseBranch: (String) -> Void
    let onRefreshGitBranches: () -> Void
    let onRefreshUsageStatus: () async -> Void
    let onSelectAccessMode: (CodexAccessMode) -> Void
    let canHandOffToWorktree: Bool
    let onTapCreateWorktree: () -> Void
    let onSetPlanModeArmed: (Bool) -> Void
    let onResumeQueue: () -> Void
    let onStopTurn: (String?) -> Void
    let onSend: () -> Void

    // MARK: - Constants

    private let metaLabelColor = Color(.secondaryLabel)
    private var metaTextFont: Font { AppFont.subheadline() }
    private var metaSymbolFont: Font { AppFont.system(size: 11, weight: .regular) }
    private let metaSymbolSize: CGFloat = 12
    private let brainSymbolSize: CGFloat = 8
    private let reasoningSymbolName = "brain"
    private let reasoningSymbolIsAsset = true
    private var metaChevronFont: Font { AppFont.system(size: 9, weight: .regular) }
    private let metaVerticalPadding: CGFloat = 6
    private let plusTapTargetSide: CGFloat = 22

    private var sendButtonIconColor: Color {
        if isSendDisabled { return Color(.systemGray2) }
        return Color(.systemBackground)
    }

    private var sendButtonBackgroundColor: Color {
        if isSendDisabled { return Color(.systemGray5) }
        return Color(.label)
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            settingsMenu
            if isPlanModeArmed {
                Divider()
                    .frame(height: 16)
                planModeIndicator
            }
            Spacer(minLength: 0)

            if isQueuePaused && queuedCount > 0 {
                Button {
                    HapticFeedback.shared.triggerImpactFeedback(style: .light)
                    onResumeQueue()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(AppFont.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(.systemBackground))
                        .frame(width: 28, height: 28)
                        .background(Color(.systemGray2), in: Circle())
                }
                .accessibilityLabel("Resume queued messages")
            }

            if isThreadRunning {
                Button {
                    HapticFeedback.shared.triggerImpactFeedback()
                    onStopTurn(activeTurnID)
                } label: {
                    Image(systemName: "stop.fill")
                        .font(AppFont.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(.systemBackground))
                        .frame(width: 32, height: 32)
                        .background(Color(.label), in: Circle())
                }
                .accessibilityLabel("Stop response")
            } else {
                Button {
                    HapticFeedback.shared.triggerImpactFeedback()
                    if isSendDisabled {
                        onTapVoice()
                    } else {
                        onSend()
                    }
                } label: {
                    combinedActionButtonLabel
                }
                .overlay(alignment: .topTrailing) {
                    if queuedCount > 0 {
                        queueBadge
                            .offset(x: 8, y: -8)
                    }
                }
                .disabled(isSendDisabled && voiceButtonPresentation.isDisabled)
                .accessibilityLabel(isSendDisabled ? voiceButtonPresentation.accessibilityLabel : "Send message")
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        .padding(.top, 2)
    }

    private var combinedActionButtonLabel: some View {
        Group {
            if isSendDisabled && voiceButtonPresentation.showsProgress {
                ProgressView()
                    .tint(voiceButtonPresentation.foregroundColor)
                    .frame(width: 32, height: 32)
                    .background(voiceButtonPresentation.backgroundColor, in: Circle())
            } else if isSendDisabled {
                Image(systemName: voiceButtonPresentation.systemImageName)
                    .font(AppFont.system(size: 12, weight: .bold))
                    .foregroundStyle(voiceButtonPresentation.foregroundColor)
                    .frame(width: 32, height: 32)
                    .background(voiceButtonPresentation.backgroundColor, in: Circle())
            } else {
                Image(systemName: "arrow.up")
                    .font(AppFont.system(size: 12, weight: .bold))
                    .foregroundStyle(sendButtonIconColor)
                    .frame(width: 32, height: 32)
                    .background(sendButtonBackgroundColor, in: Circle())
            }
        }
    }

    // MARK: - Menus

    private var settingsMenu: some View {
        Menu {
            Section("Add") {
                Button("Photo library") {
                    HapticFeedback.shared.triggerImpactFeedback()
                    onTapAddImage()
                }
                .disabled(remainingAttachmentSlots == 0)

                Button("Take a photo") {
                    HapticFeedback.shared.triggerImpactFeedback()
                    onTapTakePhoto()
                }
                .disabled(remainingAttachmentSlots == 0)
            }

            Section("Mode") {
                Toggle(isOn: Binding(
                    get: { isPlanModeArmed },
                    set: { newValue in
                        HapticFeedback.shared.triggerImpactFeedback(style: .light)
                        onSetPlanModeArmed(newValue)
                    }
                )) {
                    Label("Plan mode", systemImage: "checklist")
                }
            }

            modelMenuContent
            reasoningMenuContent
            speedMenuContent
            accessMenuContent
            runtimeMenuContent
            branchMenuContent
            usageMenuContent
        } label: {
            Image(systemName: "plus")
                .font(metaTextFont)
                .fontWeight(.regular)
                .frame(width: plusTapTargetSide, height: plusTapTargetSide)
                .contentShape(Capsule())
        }
        .tint(metaLabelColor)
        .disabled(isComposerInteractionLocked)
        .accessibilityLabel("Composer settings")
    }

    @ViewBuilder
    private var modelMenuContent: some View {
        Section("Model") {
            if isLoadingModels {
                Text("Loading models...")
            } else if orderedModelOptions.isEmpty {
                Text("No models available")
            } else {
                ForEach(orderedModelOptions, id: \.id) { model in
                    Button {
                        HapticFeedback.shared.triggerImpactFeedback(style: .light)
                        runtimeActions.selectModel(model.id)
                    } label: {
                        if selectedModelID == model.id {
                            Label(TurnComposerMetaMapper.modelTitle(for: model), systemImage: "checkmark")
                        } else {
                            Text(TurnComposerMetaMapper.modelTitle(for: model))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var reasoningMenuContent: some View {
        Section("Thinking Effort") {
            Button {
                HapticFeedback.shared.triggerImpactFeedback(style: .light)
                runtimeActions.selectAutomaticReasoning()
            } label: {
                if runtimeState.selectedReasoningEffort == nil {
                    Label("Automatic (\(runtimeState.selectedReasoningTitle))", systemImage: "checkmark")
                } else {
                    Text("Automatic (\(runtimeState.selectedReasoningTitle))")
                }
            }
            .disabled(runtimeState.reasoningMenuDisabled)

            if runtimeState.reasoningDisplayOptions.isEmpty {
                Text("No thinking options")
            } else {
                ForEach(runtimeState.reasoningDisplayOptions, id: \.id) { option in
                    Button {
                        HapticFeedback.shared.triggerImpactFeedback(style: .light)
                        runtimeActions.selectReasoning(option.effort)
                    } label: {
                        if runtimeState.selectedReasoningEffort != nil && runtimeState.isSelectedReasoning(option.effort) {
                            Label(option.title, systemImage: "checkmark")
                        } else {
                            Text(option.title)
                        }
                    }
                    .disabled(runtimeState.reasoningMenuDisabled)
                }
            }
        }
    }

    @ViewBuilder
    private var speedMenuContent: some View {
        Section("Speed") {
            Button {
                HapticFeedback.shared.triggerImpactFeedback(style: .light)
                runtimeActions.selectServiceTier(nil)
            } label: {
                if runtimeState.isSelectedServiceTier(nil) {
                    Label("Normal", systemImage: "checkmark")
                } else {
                    Text("Normal")
                }
            }

            ForEach(CodexServiceTier.allCases, id: \.rawValue) { tier in
                Button {
                    HapticFeedback.shared.triggerImpactFeedback(style: .light)
                    runtimeActions.selectServiceTier(tier)
                } label: {
                    if runtimeState.isSelectedServiceTier(tier) {
                        Label(tier.displayName, systemImage: "checkmark")
                    } else {
                        Text(tier.displayName)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var accessMenuContent: some View {
        Section("Access") {
            ForEach(CodexAccessMode.allCases, id: \.rawValue) { mode in
                Button {
                    HapticFeedback.shared.triggerImpactFeedback(style: .light)
                    onSelectAccessMode(mode)
                } label: {
                    if selectedAccessMode == mode {
                        Label(mode.menuTitle, systemImage: "checkmark")
                    } else {
                        Text(mode.menuTitle)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var runtimeMenuContent: some View {
        Section("Continue In") {
            Button {
                HapticFeedback.shared.triggerImpactFeedback(style: .light)
                if let url = URL(string: "https://chatgpt.com/codex") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Cloud", systemImage: "cloud")
            }

            Button {
                HapticFeedback.shared.triggerImpactFeedback(style: .light)
                onTapCreateWorktree()
            } label: {
                Label(
                    isCreatingGitWorktree
                        ? "Preparing worktree..."
                        : isWorktreeProject ? "Hand off to Local" : isEmptyThread ? "New worktree" : "Hand off to Worktree",
                    systemImage: isWorktreeProject ? "laptopcomputer" : "externaldrive.connected.to.line.below"
                )
            }
            .disabled(!canHandOffToWorktree || isCreatingGitWorktree || isSwitchingGitBranch)

            Button {
            } label: {
                Label("Local", systemImage: "laptopcomputer")
            }
            .disabled(true)
        }
    }

    @ViewBuilder
    private var branchMenuContent: some View {
        if showsGitBranchSelector {
            Section("Branch") {
                if isLoadingGitBranchTargets {
                    Text("Loading branches...")
                } else if availableGitBranchTargets.isEmpty {
                    Text(currentGitBranch.isEmpty ? "No branches available" : "Current: \(currentGitBranch)")
                } else {
                    branchButton(for: gitDefaultBranch)

                    ForEach(availableGitBranchTargets.filter { $0 != gitDefaultBranch }, id: \.self) { branch in
                        branchButton(for: branch)
                    }
                }

                Button {
                    HapticFeedback.shared.triggerImpactFeedback(style: .light)
                    onRefreshGitBranches()
                } label: {
                    Label("Refresh branches", systemImage: "arrow.clockwise")
                }
                .disabled(!isGitBranchSelectorEnabled || isLoadingGitBranchTargets || isSwitchingGitBranch)
            }
        }
    }

    @ViewBuilder
    private func branchButton(for branch: String) -> some View {
        if !branch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let checkedOutElsewhere = gitBranchesCheckedOutElsewhere.contains(branch)
            let checkedOutPath = gitWorktreePathsByBranch[branch]
            let isDisabled = remodexCurrentBranchSelectionIsDisabled(
                branch: branch,
                currentBranch: currentGitBranch,
                gitBranchesCheckedOutElsewhere: gitBranchesCheckedOutElsewhere,
                gitWorktreePathsByBranch: gitWorktreePathsByBranch,
                allowsSelectingCurrentBranch: true
            )

            Button {
                HapticFeedback.shared.triggerImpactFeedback(style: .light)
                onSelectGitBranch(branch)
            } label: {
                let title = checkedOutElsewhere && checkedOutPath != nil
                    ? "\(branch) (worktree)"
                    : branch
                if branch == currentGitBranch {
                    Label(title, systemImage: "checkmark")
                } else {
                    Text(title)
                }
            }
            .disabled(!isGitBranchSelectorEnabled || isLoadingGitBranchTargets || isSwitchingGitBranch || isDisabled)
        }
    }

    @ViewBuilder
    private var usageMenuContent: some View {
        Section("Usage") {
            if let contextWindowUsage {
                Text("\(contextWindowUsage.percentUsed)% used · \(contextWindowUsage.tokensUsedFormatted)/\(contextWindowUsage.tokenLimitFormatted)")
            } else if let rateLimitsErrorMessage {
                Text(rateLimitsErrorMessage)
            } else {
                Text("Usage not loaded")
            }

            Button {
                HapticFeedback.shared.triggerImpactFeedback(style: .light)
                Task {
                    await onRefreshUsageStatus()
                }
            } label: {
                Label("Refresh usage", systemImage: "arrow.clockwise")
            }
        }
    }

    private var planModeIndicator: some View {
        HStack(spacing: 5) {
            Image(systemName: "checklist")
                .font(metaSymbolFont)
            Text("Plan")
                .font(metaTextFont)
                .fontWeight(.regular)
                .lineLimit(1)
        }
        .padding(.vertical, metaVerticalPadding)
        .padding(.horizontal, 4)
        .foregroundStyle(Color(.plan))
    }


    private var queueBadge: some View {
        HStack(spacing: 3) {
            if isQueuePaused {
                Image(systemName: "pause.fill")
                    .font(AppFont.system(size: 8, weight: .bold))
            }
            Text("\(queuedCount)")
                .font(AppFont.caption2(weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule().fill(isQueuePaused ? Color(.systemGray3) : Color(.systemGray4))
        )
    }

    // MARK: - Shared Label

    private func composerMenuLabel(
        title: String,
        leadingImageName: String? = nil,
        leadingImageIsSystem: Bool = true
    ) -> some View {
        HStack(spacing: 6) {
            if let leadingImageName {
                Group {
                    if leadingImageIsSystem {
                        Image(systemName: leadingImageName)
                            .font(metaSymbolFont)
                    } else {
                        Image(leadingImageName)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: metaSymbolSize, height: metaSymbolSize)
                    }
                }
            }

            Text(title)
                .font(metaTextFont)
                .fontWeight(.regular)
                .lineLimit(1)

            Image(systemName: "chevron.down")
                .font(metaChevronFont)
        }
        .padding(.vertical, metaVerticalPadding)
        .padding(.horizontal, 4)
        .foregroundStyle(metaLabelColor)
        // Keep adjacent menus from borrowing each other's touch region when the
        // phone composer gets tight while the keyboard is up.
        .fixedSize(horizontal: true, vertical: false)
        .contentShape(Rectangle())
    }
}

// Keeps the mic button state and styling decisions outside the layout code.
struct TurnComposerVoiceButtonPresentation {
    let systemImageName: String
    let foregroundColor: Color
    let backgroundColor: Color
    let accessibilityLabel: String
    let isDisabled: Bool
    let showsProgress: Bool
    let hasCircleBackground: Bool
}
