// FILE: OnboardingView.swift
// Purpose: Split onboarding flow with swipeable pages and a fixed bottom bar.
// Layer: View
// Exports: OnboardingView
// Depends on: SwiftUI, OnboardingWelcomePage, OnboardingFeaturesPage, OnboardingSetupPromptPage

import SwiftUI

struct OnboardingView: View {
    let onContinue: () -> Void
    @State private var currentPage = 0

    private static let pageCount = 3
    static let setupPromptPageIndex = 2

    init(initialPage: Int = 0, onContinue: @escaping () -> Void) {
        self.onContinue = onContinue
        let clampedInitialPage = min(max(initialPage, 0), Self.pageCount - 1)
        _currentPage = State(initialValue: clampedInitialPage)
    }

    var body: some View {
        ZStack {
            Color(.secondarySystemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    OnboardingWelcomePage()
                        .tag(0)

                    OnboardingFeaturesPage()
                        .tag(1)

                    OnboardingSetupPromptPage()
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                bottomBar
            }
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 20) {
            // Animated pill dots
            HStack(spacing: 8) {
                ForEach(0..<Self.pageCount, id: \.self) { i in
                    Capsule()
                        .fill(i == currentPage ? Color.primary : Color.secondary.opacity(0.28))
                        .frame(width: i == currentPage ? 24 : 8, height: 8)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentPage)

            // CTA button
            actionButton
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [
                    Color(.secondarySystemBackground).opacity(0),
                    Color(.secondarySystemBackground).opacity(0.92),
                    Color(.secondarySystemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 50)
            .offset(y: -50),
            alignment: .top
        )
    }

    @ViewBuilder
    private var actionButton: some View {
        Button(action: handleContinue) {
            HStack(spacing: 10) {
                if let buttonIcon {
                    Image(systemName: buttonIcon)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(buttonTitle)
                    .font(AppFont.body(weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.black, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - State

    private var buttonTitle: String {
        switch currentPage {
        case 0: return "Get Started"
        case 1: return "Set Up"
        case Self.pageCount - 1: return "Scan QR Code"
        default: return "Continue"
        }
    }

    private var buttonIcon: String? {
        currentPage == Self.pageCount - 1 ? "qrcode" : nil
    }

    private func handleContinue() {
        HapticFeedback.shared.triggerImpactFeedback(style: .light)
        if currentPage < Self.pageCount - 1 {
            advanceToNextPage()
        } else {
            onContinue()
        }
    }

    private func advanceToNextPage() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPage += 1
        }
    }
}

// MARK: - Previews

#Preview("Full Flow") {
    OnboardingView {
        print("Continue tapped")
    }
}

#Preview("Light Override") {
    OnboardingView {
        print("Continue tapped")
    }
    .preferredColorScheme(.light)
}
