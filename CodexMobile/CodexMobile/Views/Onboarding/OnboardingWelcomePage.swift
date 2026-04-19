// FILE: OnboardingWelcomePage.swift
// Purpose: Welcome page for the onboarding flow.
// Layer: View
// Exports: OnboardingWelcomePage
// Depends on: SwiftUI, AppFont

import SwiftUI

struct OnboardingWelcomePage: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.97, blue: 0.99),
                    Color(red: 0.93, green: 0.94, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
                .ignoresSafeArea()

            Circle()
                .fill(Color(red: 0.78, green: 0.85, blue: 0.96).opacity(0.28))
                .frame(width: 280, height: 280)
                .blur(radius: 24)
                .offset(x: 108, y: -188)

            Circle()
                .fill(Color.white.opacity(0.7))
                .frame(width: 220, height: 220)
                .blur(radius: 18)
                .offset(x: -118, y: -78)

            VStack(spacing: 24) {
                Spacer(minLength: 34)

                VStack(spacing: 20) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Local-first setup")
                            .font(AppFont.caption(weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.78))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )

                    heroCard

                    VStack(spacing: 8) {
                        Text("Harmony")
                            .font(AppFont.system(size: 32, weight: .bold))
                            .foregroundStyle(.primary)

                        Text("Control Codex from your iPhone.")
                            .font(AppFont.subheadline(weight: .regular))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    HStack(spacing: 10) {
                        valueChip(icon: "desktopcomputer", title: "Runs on your Mac")
                        valueChip(icon: "iphone.gen3", title: "Live on iPhone")
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 120)
            }
        }
    }

    private var heroCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.98),
                            Color(red: 0.95, green: 0.96, blue: 0.99)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)

            Circle()
                .fill(Color(red: 0.86, green: 0.90, blue: 0.97).opacity(0.65))
                .frame(width: 180, height: 180)
                .blur(radius: 10)
                .offset(y: -8)

            VStack(spacing: 18) {
                HStack {
                    smallStatusPill(icon: "sparkles", label: "Private relay")
                    Spacer()
                    smallStatusPill(icon: "bolt.fill", label: "Fast handoff")
                }

                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.88))
                        .frame(width: 136, height: 136)

                    Image(systemName: "macbook.and.iphone")
                        .font(.system(size: 58, weight: .medium))
                        .foregroundStyle(Color(red: 0.30, green: 0.34, blue: 0.42))
                }
                .shadow(color: Color.black.opacity(0.06), radius: 18, y: 8)

                HStack(spacing: 10) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)

                    connectionDots

                    Image(systemName: "iphone.gen3")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .frame(height: 278)
    }

    private var connectionDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index == 1 ? Color.primary.opacity(0.45) : Color.primary.opacity(0.18))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private func valueChip(icon: String, title: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(title)
                .font(AppFont.caption(weight: .semibold))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    private func smallStatusPill(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(label)
                .font(AppFont.caption2(weight: .semibold))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.8))
        )
    }
}

#Preview {
    OnboardingWelcomePage()
}
