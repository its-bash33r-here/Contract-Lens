//
//  DesignSystem.swift
//  lawgpt
//
//  Created by Bash33r on 01/12/25.
//

import SwiftUI
import UIKit

/// Design system constants for legal professional app
struct DesignSystem {
    
    // MARK: - Colors
    
    /// App logo deep navy blue accent color
    /// RGB: 30, 58, 138 (#1E3A8A - Deep Navy Blue for legal theme)
    static let accentColor = Color(red: 30.0/255.0, green: 58.0/255.0, blue: 138.0/255.0)
    
    /// App logo deep navy blue highlight color (same as accent for consistency)
    static let highlightColor = Color(red: 30.0/255.0, green: 58.0/255.0, blue: 138.0/255.0)
    
    /// Lighter variant for backgrounds/highlights
    static let accentLight = Color(red: 30.0/255.0, green: 58.0/255.0, blue: 138.0/255.0).opacity(0.15)
    
    /// Highlight light variant
    static let highlightLight = Color(red: 30.0/255.0, green: 58.0/255.0, blue: 138.0/255.0).opacity(0.15)
    
    /// Darker variant for pressed states
    static let accentDark = Color(red: 20.0/255.0, green: 40.0/255.0, blue: 100.0/255.0)
    
    /// Lighter legal blue for gradients and backgrounds
    static let legalBlueLight = Color(red: 59.0/255.0, green: 89.0/255.0, blue: 152.0/255.0)
    
    /// Darker legal blue for pressed states and gradients
    static let legalBlueDark = Color(red: 20.0/255.0, green: 40.0/255.0, blue: 100.0/255.0)
    
    /// Status colors
    static let successColor = Color.green
    static let warningColor = Color(red: 1.0, green: 0.58, blue: 0.0) // Amber
    static let errorColor = Color.red
    
    /// Neutral grays for backgrounds
    static let backgroundGray = Color(.systemGray6)
    static let separatorGray = Color(.separator)
    
    // MARK: - Spacing
    
    /// Spacing between messages (increased for readability)
    static let messageSpacing: CGFloat = 36
    
    /// Spacing between paragraphs (increased for legal content)
    static let paragraphSpacing: CGFloat = 32
    
    /// Horizontal content padding
    static let horizontalPadding: CGFloat = 24
    
    /// Source card spacing
    static let sourceCardSpacing: CGFloat = 12
    
    /// Increased spacing for legal readability
    static let legalContentSpacing: CGFloat = 32
    
    /// Line spacing for body text (increased for better readability)
    static let bodyLineSpacing: CGFloat = 8
    
    /// Section divider spacing
    static let sectionDividerSpacing: CGFloat = 24
    
    // MARK: - Typography
    
    /// Typography system for legal professional app
    /// Uses SF Pro Display for headings, SF Pro Text for body
    
    /// Heading 1 font (24pt) - SF Pro Display with Dynamic Type support
    static func heading1Font() -> Font {
        .system(.title, design: .default).weight(.bold)
    }
    
    /// Heading 2 font (20pt) - SF Pro Display with Dynamic Type support
    static func heading2Font() -> Font {
        .system(.title2, design: .default).weight(.semibold)
    }
    
    /// Heading 3 font (18pt) - SF Pro Display with Dynamic Type support
    static func heading3Font() -> Font {
        .system(.title3, design: .default).weight(.semibold)
    }
    
    /// Body font (16pt base) - SF Pro Text with Dynamic Type support
    static func bodyFont() -> Font {
        .system(.body, design: .default)
    }
    
    /// Secondary body font (14pt) - SF Pro Text with Dynamic Type support
    static func secondaryBodyFont() -> Font {
        .system(.subheadline, design: .default)
    }
    
    /// Caption font (12pt) with Dynamic Type support
    static func captionFont() -> Font {
        .system(.caption, design: .default)
    }
    
    /// Small caption font (11pt) with Dynamic Type support
    static func smallCaptionFont() -> Font {
        .system(.caption2, design: .default)
    }
    
    /// Legal values font (15pt monospace) with Dynamic Type support
    static func legalValueFont() -> Font {
        .system(size: UIFontMetrics.default.scaledValue(for: 15), weight: .regular, design: .monospaced)
    }
    
    /// Base body font size (16px)
    static let bodyFontSize: CGFloat = 16
    
    /// Line height multiplier for legal content (1.6-1.7 ratio for readability)
    static let bodyLineHeight: CGFloat = 1.65
    
    /// Legal content line height (larger for complex terminology)
    static let legalLineHeight: CGFloat = 1.7
    
    // MARK: - Dynamic Type Support
    
    /// Get scaled font size respecting Dynamic Type
    static func scaledFontSize(base: CGFloat) -> CGFloat {
        let contentSize = UIApplication.shared.preferredContentSizeCategory
        return UIFontMetrics.default.scaledValue(for: base, compatibleWith: UITraitCollection(preferredContentSizeCategory: contentSize))
    }
    
    // MARK: - Animation
    
    /// Message fade-in animation duration
    static let messageFadeDuration: Double = 0.4
    
    /// Message slide-up distance
    static let messageSlideDistance: CGFloat = 10
    
    /// Source card press animation duration
    static let pressAnimationDuration: Double = 0.15
    
    /// Source card press scale
    static let pressScale: CGFloat = 0.97
    
    /// Follow-up suggestion stagger delay
    static let followUpStaggerDelay: Double = 0.1
    
    /// Related topics expand animation duration
    static let relatedTopicsExpandDuration: Double = 0.5
}

// MARK: - Color Extensions

extension Color {
    /// App logo deep navy blue accent color
    static let legalAccent = DesignSystem.accentColor
    
    /// App logo deep navy blue for highlights
    static let legalHighlight = DesignSystem.highlightColor
    
    /// Accent light variant
    static let accentLight = DesignSystem.accentLight
    
    /// Highlight light variant
    static let highlightLight = DesignSystem.highlightLight
    
    /// Accent dark variant
    static let accentDark = DesignSystem.accentDark
    
    /// Status colors
    static let legalSuccess = DesignSystem.successColor
    static let legalWarning = DesignSystem.warningColor
    static let legalError = DesignSystem.errorColor
    
    /// Background colors
    static let legalBackground = DesignSystem.backgroundGray
    static let legalSeparator = DesignSystem.separatorGray
}

// MARK: - Animation Extensions

extension Animation {
    /// Standard message appearance animation
    static var messageAppearance: Animation {
        .easeOut(duration: DesignSystem.messageFadeDuration)
    }
    
    /// Source card press animation (response: 0.3, damping: 0.7)
    static var cardPress: Animation {
        .spring(response: 0.3, dampingFraction: 0.7)
    }
    
    /// Follow-up suggestion stagger animation
    static var followUpStagger: Animation {
        .easeOut(duration: 0.3)
    }
    
    /// Related topics expand animation (spring)
    static var relatedTopicsExpand: Animation {
        .spring(response: 0.5, dampingFraction: 0.8)
    }
    
    /// Respects Reduce Motion accessibility setting
    static var accessible: Animation {
        UIAccessibility.isReduceMotionEnabled ? Animation.linear(duration: 0) : .default
    }
}
