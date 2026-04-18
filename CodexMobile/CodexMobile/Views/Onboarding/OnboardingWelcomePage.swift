// FILE: OnboardingWelcomePage.swift
// Purpose: Welcome page for the onboarding flow.
// Layer: View
// Exports: OnboardingWelcomePage
// Depends on: SwiftUI, AppFont

import SwiftUI

struct OnboardingWelcomePage: View {
    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)
                .ignoresSafeArea()

            VStack(spacing: 26) {
                Spacer(minLength: 34)

                VStack(spacing: 22) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color(.systemBackground))

                        VStack(spacing: 18) {
                            ZStack {
                                Circle()
                                    .fill(Color(.tertiarySystemFill))
                                    .frame(width: 116, height: 116)

                                Image(systemName: "iphone.gen3")
                                    .font(.system(size: 56, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 10) {
                                Image(systemName: "desktopcomputer")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.secondary)

                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(Color.secondary.opacity(0.35))
                                    .frame(width: 32, height: 2)

                                Image(systemName: "iphone.gen3")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(height: 260)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )

                    VStack(spacing: 8) {
                        Text("Chorus Remote")
                            .font(AppFont.system(size: 32, weight: .bold))
                            .foregroundStyle(.primary)

                        Text("Control Codex from your iPhone.")
                            .font(AppFont.subheadline(weight: .regular))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 11, weight: .medium))
                        Text("End-to-end encrypted")
                            .font(AppFont.caption(weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 120)
            }
        }
    }
}

#Preview {
    OnboardingWelcomePage()
}
