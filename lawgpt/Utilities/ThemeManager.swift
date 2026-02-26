//
//  ThemeManager.swift
//  lawgpt
//
//  Created by Bash33r on 01/12/25.
//

import SwiftUI
import Combine
import UIKit

/// Available theme options for the app
enum Theme: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    /// Icon name for each theme option
    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    /// Color scheme for this theme
    var colorScheme: ColorScheme {
        switch self {
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Manages theme preferences for the app
@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var currentTheme: Theme = .light {
        didSet {
            saveTheme()
            applyAppearance()
        }
    }

    private let themeKey = "app_theme_preference"

    private init() {
        loadTheme()
    }

    /// Load saved theme from UserDefaults
    private func loadTheme() {
        if let savedThemeRaw = UserDefaults.standard.string(forKey: themeKey),
           let savedTheme = Theme(rawValue: savedThemeRaw) {
            currentTheme = savedTheme
        } else {
            currentTheme = .light // Default to light
        }
        applyAppearance()
    }

    /// Save current theme to UserDefaults
    private func saveTheme() {
        UserDefaults.standard.set(currentTheme.rawValue, forKey: themeKey)
    }

    /// Apply appearance immediately to all active windows
    private func applyAppearance() {
        #if os(iOS)
        // Safety check: Ensure UIApplication is available before accessing
        guard UIApplication.shared.connectedScenes.count > 0 else {
            // If scenes aren't ready yet, defer application
            DispatchQueue.main.async { [weak self] in
                self?.applyAppearance()
            }
            return
        }
        
        let style: UIUserInterfaceStyle = (currentTheme == .dark) ? .dark : .light
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
        #endif
    }
}