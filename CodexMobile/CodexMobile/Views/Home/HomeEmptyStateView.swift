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
        GeometryReader { proxy in
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                loadingBackdrop(size: proxy.size)
                    .ignoresSafeArea()

                VStack(spacing: 28) {
                    Spacer(minLength: 0)

                    VStack(spacing: 10) {
                        Text("Harmony is loading...")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .multilineTextAlignment(.center)
                            .tracking(-0.7)

                        Text("Connecting to Codex...")
                            .font(.system(size: 19, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)

                    HarmonyLoadingAnimationView()
                        .frame(width: min(proxy.size.width * 0.76, 320), height: min(proxy.size.width * 0.76, 320))
                        .padding(.top, 8)

                    HarmonyLoadingBarView()
                        .frame(width: min(proxy.size.width * 0.62, 240), height: 10)
                        .padding(.top, -4)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
            }
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

    @ViewBuilder
    private func loadingBackdrop(size: CGSize) -> some View {
        let major = max(size.width, size.height)

        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.black.opacity(0.07),
                            Color.black.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 12,
                        endRadius: major * 0.42
                    )
                )
                .frame(width: major * 0.82, height: major * 0.82)
                .offset(x: -major * 0.16, y: -major * 0.18)
                .blur(radius: 18)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.black.opacity(0.045),
                            Color.black.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: major * 0.34
                    )
                )
                .frame(width: major * 0.68, height: major * 0.68)
                .offset(x: major * 0.2, y: major * 0.16)
                .blur(radius: 24)
        }
    }

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

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.black.opacity(0.09),
                                Color.black.opacity(0.04),
                                Color.black.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .scaleEffect(0.88 + CGFloat((sin(elapsed * 1.25) + 1) * 0.04))
                    .blur(radius: 18)

                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let minDimension = min(size.width, size.height)
                    let ringConfigs: [(radius: CGFloat, lineWidth: CGFloat, opacity: Double, speed: Double, length: Double)] = [
                        (minDimension * 0.23, 1.4, 0.22, 0.55, 0.52),
                        (minDimension * 0.31, 1.8, 0.16, -0.38, 0.44),
                        (minDimension * 0.39, 1.2, 0.12, 0.24, 0.36)
                    ]

                    for ring in ringConfigs {
                        let rect = CGRect(
                            x: center.x - ring.radius,
                            y: center.y - ring.radius,
                            width: ring.radius * 2,
                            height: ring.radius * 2
                        )

                        let start = elapsed * ring.speed
                        let normalizedStart = start - floor(start)
                        let end = normalizedStart + ring.length
                        var path = Path()
                        path.addEllipse(in: rect)

                        context.stroke(
                            path.trimmedPath(from: normalizedStart, to: min(end, 1)),
                            with: .color(.black.opacity(ring.opacity)),
                            style: StrokeStyle(lineWidth: ring.lineWidth, lineCap: .round)
                        )

                        if end > 1 {
                            context.stroke(
                                path.trimmedPath(from: 0, to: end - 1),
                                with: .color(.black.opacity(ring.opacity)),
                                style: StrokeStyle(lineWidth: ring.lineWidth, lineCap: .round)
                            )
                        }
                    }

                    let dotConfigs: [(orbit: CGFloat, size: CGFloat, speed: Double, phase: Double, opacity: Double)] = [
                        (minDimension * 0.23, 12, 1.05, 0.0, 0.95),
                        (minDimension * 0.31, 9, -0.82, 1.7, 0.72),
                        (minDimension * 0.39, 7, 0.58, 3.2, 0.48)
                    ]

                    for dot in dotConfigs {
                        let angle = elapsed * dot.speed + dot.phase
                        let position = CGPoint(
                            x: center.x + cos(angle) * dot.orbit,
                            y: center.y + sin(angle) * dot.orbit
                        )
                        let rect = CGRect(
                            x: position.x - dot.size / 2,
                            y: position.y - dot.size / 2,
                            width: dot.size,
                            height: dot.size
                        )
                        context.fill(Path(ellipseIn: rect), with: .color(.black.opacity(dot.opacity)))
                    }
                }

                VStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(0.92))
                        .frame(width: 66, height: 14)

                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black.opacity(0.86))
                            .frame(width: 14, height: 66)

                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black.opacity(0.62))
                            .frame(width: 14, height: 66)

                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black.opacity(0.38))
                            .frame(width: 14, height: 66)
                    }
                }
                .offset(y: CGFloat(sin(elapsed * 1.35)) * 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .drawingGroup()
        .accessibilityHidden(true)
    }
}

private struct HarmonyLoadingBarView: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate

            GeometryReader { proxy in
                let width = proxy.size.width
                let travel = width + 72
                let normalized = elapsed.remainder(dividingBy: 1.7) / 1.7
                let headX = normalized * travel - 36

                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.black.opacity(0.08))
                        .frame(height: 2)

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.0),
                                    Color.black.opacity(0.78),
                                    Color.black.opacity(0.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 72, height: 4)
                        .offset(x: headX)
                        .blur(radius: 0.3)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .accessibilityLabel("Loading")
    }
}
