//
//  HapticManager.swift
//  lawgpt
//
//  Created by Bash33r on 01/12/25.
//

import UIKit
import SwiftUI

/// Centralized haptic feedback manager for legal app interactions
/// Respects Reduce Motion accessibility setting
@MainActor
class HapticManager {
    static let shared = HapticManager()
    
    private var impactGenerator: UIImpactFeedbackGenerator?
    private var notificationGenerator: UINotificationFeedbackGenerator?
    private var selectionGenerator: UISelectionFeedbackGenerator?
    
    private init() {
        // Pre-warm generators for better performance
        impactGenerator = UIImpactFeedbackGenerator(style: .light)
        impactGenerator?.prepare()
        
        notificationGenerator = UINotificationFeedbackGenerator()
        notificationGenerator?.prepare()
        
        selectionGenerator = UISelectionFeedbackGenerator()
        selectionGenerator?.prepare()
    }
    
    // MARK: - Check Reduce Motion
    
    private var shouldReduceMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }
    
    // MARK: - Impact Haptics
    
    /// Light impact - for subtle interactions (message sent, follow-up selected)
    func lightImpact() {
        guard !shouldReduceMotion else { return }
        impactGenerator?.impactOccurred(intensity: 0.5)
    }
    
    /// Medium impact - for source taps, button presses
    func mediumImpact() {
        guard !shouldReduceMotion else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// Heavy impact - for important actions
    func heavyImpact() {
        guard !shouldReduceMotion else { return }
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // MARK: - Notification Haptics
    
    /// Success pattern - for completed actions (export, save)
    func success() {
        guard !shouldReduceMotion else { return }
        notificationGenerator?.notificationOccurred(.success)
    }
    
    /// Warning pattern - for legal disclaimers, important notices
    func warning() {
        guard !shouldReduceMotion else { return }
        notificationGenerator?.notificationOccurred(.warning)
    }
    
    /// Error pattern - for API failures, invalid input
    func error() {
        guard !shouldReduceMotion else { return }
        notificationGenerator?.notificationOccurred(.error)
    }
    
    // MARK: - Selection Haptics
    
    /// Selection feedback - for picking options, toggles
    func selection() {
        guard !shouldReduceMotion else { return }
        selectionGenerator?.selectionChanged()
    }
    
    // MARK: - Custom Patterns
    
    /// Continuous light feedback for voice recording
    func startRecording() {
        guard !shouldReduceMotion else { return }
        lightImpact()
    }
    
    /// Stop recording feedback
    func stopRecording() {
        guard !shouldReduceMotion else { return }
        lightImpact()
    }
    
    /// Message sent feedback
    func messageSent() {
        lightImpact()
    }
    
    /// Source tapped feedback
    func sourceTapped() {
        mediumImpact()
    }
    
    /// Follow-up selected feedback
    func followUpSelected() {
        lightImpact()
    }
    
    /// Export completed feedback
    func exportCompleted() {
        success()
    }
    
    /// Error occurred feedback
    func errorOccurred() {
        error()
    }
}

// MARK: - SwiftUI Convenience Extension

extension View {
    /// Apply haptic feedback on tap
    func hapticFeedback(_ type: HapticFeedbackType) -> some View {
        self.onTapGesture {
            HapticManager.shared.perform(type)
        }
    }
}

enum HapticFeedbackType {
    case light
    case medium
    case heavy
    case success
    case warning
    case error
    case selection
    case messageSent
    case sourceTapped
    case followUpSelected
    case exportCompleted
    case errorOccurred
    case startRecording
    case stopRecording
}

extension HapticManager {
    func perform(_ type: HapticFeedbackType) {
        switch type {
        case .light:
            lightImpact()
        case .medium:
            mediumImpact()
        case .heavy:
            heavyImpact()
        case .success:
            success()
        case .warning:
            warning()
        case .error:
            error()
        case .selection:
            selection()
        case .messageSent:
            messageSent()
        case .sourceTapped:
            sourceTapped()
        case .followUpSelected:
            followUpSelected()
        case .exportCompleted:
            exportCompleted()
        case .errorOccurred:
            errorOccurred()
        case .startRecording:
            startRecording()
        case .stopRecording:
            stopRecording()
        }
    }
}
