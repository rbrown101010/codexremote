// FILE: ChorusRemoteGuidePageView.swift
// Purpose: Hosts the Chorus-style guide pages from Settings.
// Layer: View
// Exports: ChorusRemoteGuidePageView, ChorusRemoteGuidePage

import SwiftUI

enum ChorusRemoteGuidePage: String, CaseIterable, Identifiable, Hashable {
    case learn
    case platforms
    case build

    var id: String { rawValue }

    var title: String {
        switch self {
        case .learn: return "Learn"
        case .platforms: return "Platforms"
        case .build: return "Build"
        }
    }

    var iconName: String {
        switch self {
        case .learn: return "book.closed"
        case .platforms: return "square.grid.2x2"
        case .build: return "hammer"
        }
    }
}

struct ChorusRemoteGuidePageView: View {
    let page: ChorusRemoteGuidePage

    var body: some View {
        ZStack {
            ChorusRemoteBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    Text(page.title)
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundStyle(ChorusRemotePalette.ink)
                        .padding(.top, 72)

                    ChorusRemoteCardGrid(items: items)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 48)
            }
        }
        .navigationTitle(page.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var items: [ChorusRemoteCard] {
        switch page {
        case .learn:
            return [
                .init(title: "What Is an Agent?", meta: "Start here", body: "A model in a loop with tools, memory, and a job."),
                .init(title: "Narrow Beats General", meta: "Architecture", body: "Give it one job, one scorecard, one owner."),
                .init(title: "Build the Loop", meta: "Flow", body: "Input, plan, action, feedback, and a clean handoff.")
            ]
        case .platforms:
            return [
                .init(title: "Platforms", meta: "Coming soon", body: "Connect the places where your agents work."),
                .init(title: "Workspaces", meta: "Blank", body: "Add your own platform notes here later.")
            ]
        case .build:
            return [
                .init(title: "Build", meta: "Coming soon", body: "Draft and ship small agent workflows from a clean starting point."),
                .init(title: "Playbooks", meta: "Blank", body: "Keep this simple until the remote workflow is settled.")
            ]
        }
    }
}

private struct ChorusRemoteCard: Identifiable {
    let id = UUID()
    let title: String
    let meta: String
    let body: String
}

private struct ChorusRemoteCardGrid: View {
    let items: [ChorusRemoteCard]

    var body: some View {
        VStack(spacing: 18) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.title)
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                .foregroundStyle(ChorusRemotePalette.ink)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(item.meta)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(ChorusRemotePalette.secondaryInk)
                        }

                        Spacer(minLength: 12)

                        Image(systemName: "bookmark")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(ChorusRemotePalette.secondaryInk)
                    }

                    Text(item.body)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(ChorusRemotePalette.tertiaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ChorusRemotePalette.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
        }
    }
}

private enum ChorusRemotePalette {
    static let ink = Color(hex: "0A0D12")
    static let secondaryInk = Color(hex: "6E7582")
    static let tertiaryInk = Color(hex: "30353D")
    static let canvasTop = Color(hex: "F8F9FB")
    static let canvasBottom = Color(hex: "EEF2F5")
    static let accent = Color(hex: "DDEBFF")
    static let card = Color.white
}

private struct ChorusRemoteBackground: View {
    var body: some View {
        LinearGradient(
            colors: [ChorusRemotePalette.canvasTop, ChorusRemotePalette.canvasBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color.white.opacity(0.68))
                .frame(width: 220, height: 220)
                .blur(radius: 16)
                .offset(x: 70, y: -20)
        }
        .overlay(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 60, style: .continuous)
                .fill(ChorusRemotePalette.accent.opacity(0.24))
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(18))
                .offset(x: -90, y: 88)
                .blur(radius: 10)
        }
        .ignoresSafeArea()
    }
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (255, 255, 255)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
