// FILE: TerminalRunningIndicator.swift
// Purpose: Compact ">_" terminal glyph with blinking cursor, shown while an assistant block is running.
// Layer: View Component
// Exports: TerminalRunningIndicator

import SwiftUI

struct TerminalRunningIndicator: View {
    private static let spinnerVerbs: [String] = [
        "Accomplishing", "Actioning", "Actualizing", "Architecting", "Baking", "Beaming",
        "Bootstrapping", "Brewing", "Burrowing", "Calculating", "Cerebrating", "Channeling",
        "Choreographing", "Clauding", "Coalescing", "Cogitating", "Composing", "Computing",
        "Concocting", "Considering", "Contemplating", "Crafting", "Creating", "Crunching",
        "Crystallizing", "Cultivating", "Deciphering", "Deliberating", "Determining",
        "Discombobulating", "Elucidating", "Embellishing", "Enchanting", "Envisioning",
        "Fermenting", "Finagling", "Flowing", "Forging", "Forming", "Generating",
        "Gitifying", "Harmonizing", "Hashing", "Hatching", "Hullaballooing", "Hyperspacing",
        "Ideating", "Imagining", "Improvising", "Incubating", "Inferring", "Manifesting",
        "Marinating", "Metamorphosing", "Mulling", "Musing", "Nebulizing", "Noodling",
        "Orbiting", "Orchestrating", "Percolating", "Perusing", "Pondering", "Pontificating",
        "Processing", "Puzzling", "Razzmatazzing", "Recombobulating", "Ruminating",
        "Scampering", "Seasoning", "Shenaniganing", "Simmering", "Skedaddling", "Sketching",
        "Smooshing", "Spelunking", "Spinning", "Stewing", "Swirling", "Synthesizing",
        "Tempering", "Thinking", "Tinkering", "Transfiguring", "Transmuting", "Unfurling",
        "Unravelling", "Vibing", "Wandering", "Warping", "Whirring", "Whisking", "Working",
        "Wrangling", "Zesting", "Zigzagging"
    ]

    @State private var cursorOpacity: Double = 1
    @State private var currentVerb = TerminalRunningIndicator.spinnerVerbs.randomElement() ?? "Thinking"
    @State private var verbRotationTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 6) {
            glyph
            Text("\(currentVerb)...")
                .font(AppFont.caption())
                .foregroundStyle(.secondary)
                .overlay { ShimmerLabelMask() }
                .mask(
                    Text("\(currentVerb)...")
                        .font(AppFont.caption())
                )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                cursorOpacity = 0.18
            }
            startVerbRotationIfNeeded()
        }
        .onDisappear {
            verbRotationTask?.cancel()
            verbRotationTask = nil
        }
        .accessibilityLabel("Assistant is responding")
    }

    private var glyph: some View {
        HStack(alignment: .bottom, spacing: 1) {
            Text(">")
                .font(AppFont.mono(.caption2))
       
               
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(Color.secondary)
                .frame(width: 4, height: 1)
                .padding(.bottom, 2)
                .opacity(cursorOpacity)
                .offset(x: 0, y: -1)
        }
        .foregroundStyle(.secondary)
        .frame(width: 12, height: 12)
               .padding(5)
               .background(
                   Circle()
                       .fill(Color.primary.opacity(0.02))
                       .overlay(
                           Circle()
                               .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                       )
               )
               .contentShape(Circle())
    }

    private func startVerbRotationIfNeeded() {
        guard verbRotationTask == nil else {
            return
        }

        verbRotationTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                guard !Task.isCancelled else {
                    return
                }
                currentVerb = nextVerb(after: currentVerb)
            }
        }
    }

    private func nextVerb(after verb: String) -> String {
        guard Self.spinnerVerbs.count > 1 else {
            return verb
        }

        var next = verb
        while next == verb {
            next = Self.spinnerVerbs.randomElement() ?? verb
        }
        return next
    }
}

// Same gradient-sweep as ShimmerMask in TurnMessageComponents but tuned for a short label.
private struct ShimmerLabelMask: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white.opacity(0.35), location: 0.4),
                    .init(color: .white.opacity(0.35), location: 0.6),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: w * 0.5)
            .offset(x: phase * w)
            .onAppear {
                withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: false)) {
                    phase = 5
                }
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview("Terminal Running Indicator") {
    VStack(alignment: .leading, spacing: 32) {
        // Standalone
        TerminalRunningIndicator()

        // In context — simulated assistant block
        VStack(alignment: .leading, spacing: 12) {
            Text("Here is the beginning of an assistant response that is still streaming content...")
                .font(AppFont.body())
                .foregroundStyle(.primary)

            TerminalRunningIndicator()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal, 16)
    }
    .padding(.vertical, 40)
}
