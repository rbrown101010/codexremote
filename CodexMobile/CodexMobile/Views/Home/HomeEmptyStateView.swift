// FILE: HomeEmptyStateView.swift
// Purpose: Minimal home shell with branding and live connection status.
// Layer: View
// Exports: HomeEmptyStateView
// Depends on: SwiftUI

import SwiftUI

struct HomeEmptyStateView<AuthSection: View, Footer: View>: View {
    let connectionPhase: CodexConnectionPhase
    let statusMessage: String?
    let securityLabel: String?
    let trustedPairPresentation: CodexTrustedPairPresentation?
    let offlinePrimaryButtonTitle: String
    let onPrimaryAction: () -> Void
    @ViewBuilder let authSection: () -> AuthSection
    @ViewBuilder let footer: () -> Footer

    @State private var dotPulse = false
    @State private var connectionAttemptStartedAt: Date?

    var body: some View {
        Group {
            if isBusy {
                loadingBody
            } else {
                defaultBody
            }
        }
        .onAppear {
            if connectionPhase == .connecting {
                connectionAttemptStartedAt = Date()
            }
            dotPulse = isBusy
        }
        .onChange(of: connectionPhase) { _, phase in
            connectionAttemptStartedAt = phase == .connecting ? Date() : nil
            dotPulse = isBusy
        }
    }

    private var loadingBody: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.08), radius: 24, y: 12)

                    HarmonyLoadingAnimationView()
                        .frame(width: 58, height: 58)
                }
                .frame(width: 112, height: 112)

                Text("Connecting")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 28)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var defaultBody: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 22) {
                VStack(spacing: 8) {
                    Text("Harmony")
                        .font(.system(size: 31, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.center)

                    Text("Your Codex workspace, handheld.")
                        .font(AppFont.subheadline())
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 6) {
                    Circle()
                        .fill(statusDotColor)
                        .frame(width: 6, height: 6)
                        .scaleEffect(dotPulse ? 1.4 : 1.0)
                        .opacity(dotPulse ? 0.6 : 1.0)
                        .animation(
                            isBusy
                                ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                                : .default,
                            value: dotPulse
                        )

                    Text(statusLabel)
                        .font(AppFont.caption(weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(Color(.systemBackground))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )

                if let trustedPairPresentation {
                    TrustedPairSummaryView(presentation: trustedPairPresentation)
                } else if let securityLabel, !securityLabel.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 11, weight: .semibold))
                        Text(securityLabel)
                            .font(AppFont.caption(weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                }

                if let statusMessage, !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(AppFont.caption())
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Keeps reconnect or a fresh QR scan one tap away from the empty state.
                Button(action: onPrimaryAction) {
                    HStack(spacing: 10) {
                        if isBusy {
                            ProgressView()
                                .tint(.gray)
                                .scaleEffect(0.9)
                        }

                        Text(primaryButtonTitle)
                            .font(AppFont.body(weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .foregroundStyle(primaryButtonForeground)
                    .background(primaryButtonBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
                .padding(.top, 6)

                authSection()
            }
            .frame(maxWidth: 280)

            Spacer()

            footer()
                .frame(maxWidth: 280)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Harmony")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    private var isBusy: Bool {
        switch connectionPhase {
        case .connecting, .loadingChats, .syncing:
            return true
        case .offline, .connected:
            return false
        }
    }

    private var statusDotColor: Color {
        switch connectionPhase {
        case .connecting, .loadingChats, .syncing:
            return .orange
        case .connected:
            return .green
        case .offline:
            return Color(.tertiaryLabel)
        }
    }

    private var statusLabel: String {
        switch connectionPhase {
        case .connecting:
            guard let connectionAttemptStartedAt else { return "Connecting" }
            let elapsed = Date().timeIntervalSince(connectionAttemptStartedAt)
            if elapsed >= 12 { return "Still connecting…" }
            return "Connecting"
        case .loadingChats:
            return "Loading chats"
        case .syncing:
            return "Syncing"
        case .connected:
            return "Connected"
        case .offline:
            return "Offline"
        }
    }

    private var primaryButtonTitle: String {
        switch connectionPhase {
        case .connecting:
            return "Reconnecting..."
        case .loadingChats:
            return "Loading chats..."
        case .syncing:
            return "Syncing..."
        case .connected:
            return "Disconnect"
        case .offline:
            return offlinePrimaryButtonTitle
        }
    }

    private var primaryButtonBackground: Color {
        isSocketReady ? Color(.secondarySystemFill) : Color.primary
    }

    private var primaryButtonForeground: Color {
        isSocketReady ? Color.primary : Color(.systemBackground)
    }

    private var isSocketReady: Bool {
        switch connectionPhase {
        case .loadingChats, .syncing, .connected:
            return true
        case .offline, .connecting:
            return false
        }
    }
}

private struct HarmonyLoadingAnimationView: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let sweep = Angle.radians(elapsed * 1.55)

            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1.5)

                Circle()
                    .trim(from: 0.04, to: 0.28)
                    .stroke(
                        Color.primary.opacity(0.52),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(sweep)

                HStack(alignment: .center, spacing: 5) {
                    ForEach(0..<3, id: \.self) { index in
                        let wave = sin(elapsed * 2.8 + Double(index) * 0.72)
                        let height = 24 + CGFloat((wave + 1) * 5)

                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.82 - Double(index) * 0.16))
                            .frame(width: 7, height: height)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .drawingGroup()
        .accessibilityHidden(true)
    }
}
