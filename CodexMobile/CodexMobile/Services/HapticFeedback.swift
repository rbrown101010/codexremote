// FILE: HapticFeedback.swift
// Purpose: Centralized haptic feedback utility for premium button interactions.
// Layer: Service
// Exports: HapticFeedback
// Depends on: UIKit

import UIKit

@MainActor
final class HapticFeedback {
    static let shared = HapticFeedback()

    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let softImpactGenerator = UIImpactFeedbackGenerator(style: .soft)

    private init() {}

    // Uses the system notification generator for stateful success/failure cues.
    func triggerNotificationFeedback(type: UINotificationFeedbackGenerator.FeedbackType = .success) {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(type)
    }

    func triggerImpactFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let impactGenerator = generator(for: style)
        impactGenerator.prepare()
        impactGenerator.impactOccurred()
    }

    func triggerSelectionFeedback() {
        selectionGenerator.prepare()
        selectionGenerator.selectionChanged()
    }

    func triggerSidebarFeedback(isOpening: Bool) {
        triggerImpactFeedback(style: isOpening ? .medium : .soft)
    }

    func triggerThreadOpenedFeedback() {
        triggerImpactFeedback(style: .medium)
    }

    func triggerAssistantMessageFeedback() {
        triggerImpactFeedback(style: .light)
    }

    private func generator(for style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
        switch style {
        case .light:
            return lightImpactGenerator
        case .soft:
            return softImpactGenerator
        case .medium:
            return mediumImpactGenerator
        default:
            return UIImpactFeedbackGenerator(style: style)
        }
    }
}
