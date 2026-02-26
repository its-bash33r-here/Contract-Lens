//
//  AnimationHelpers.swift
//  lawgpt
//
//  Created by Bash33r on 01/12/25.
//

import SwiftUI
import UIKit

// MARK: - View Extensions for Animations

extension View {
    /// Applies fade-in animation with slight upward movement (for messages)
    func messageAppearanceAnimation(delay: Double = 0) -> some View {
        self
            .opacity(0)
            .offset(y: DesignSystem.messageSlideDistance)
            .animation(
                .messageAppearance.delay(delay),
                value: UUID() // Trigger animation on appear
            )
            .onAppear {
                withAnimation(.messageAppearance.delay(delay)) {
                    // Animation will trigger via opacity change
                }
            }
    }
    
    /// Applies fade-in with opacity animation
    func fadeIn(duration: Double = DesignSystem.messageFadeDuration, delay: Double = 0) -> some View {
        self
            .opacity(0)
            .onAppear {
                withAnimation(.easeOut(duration: duration).delay(delay)) {
                    // Will need to use @State for opacity
                }
            }
    }
}

// MARK: - Animation Modifiers

struct MessageFadeInModifier: ViewModifier {
    @State private var isVisible = false
    let delay: Double
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : DesignSystem.messageSlideDistance)
            .onAppear {
                // Respect Reduce Motion setting
                if UIAccessibility.isReduceMotionEnabled {
                    isVisible = true
                } else {
                    withAnimation(.messageAppearance.delay(delay)) {
                        isVisible = true
                    }
                }
            }
    }
}

struct CardPressModifier: ViewModifier {
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? DesignSystem.pressScale : 1.0)
            .shadow(color: isPressed ? Color.black.opacity(0.1) : Color.black.opacity(0.06),
                   radius: isPressed ? 8 : 12,
                   x: 0,
                   y: isPressed ? 2 : 4)
            .animation(.cardPress, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            // Haptic feedback
                            HapticManager.shared.mediumImpact()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

struct StaggeredFadeInModifier: ViewModifier {
    @State private var isVisible = false
    let index: Int
    let staggerDelay: Double
    
    init(index: Int, staggerDelay: Double = DesignSystem.followUpStaggerDelay) {
        self.index = index
        self.staggerDelay = staggerDelay
    }
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 10)
            .onAppear {
                if UIAccessibility.isReduceMotionEnabled {
                    isVisible = true
                } else {
                    let delay = Double(index) * staggerDelay
                    withAnimation(.followUpStagger.delay(delay)) {
                        isVisible = true
                    }
                }
            }
    }
}

struct ExpandCollapseModifier: ViewModifier {
    @Binding var isExpanded: Bool
    
    func body(content: Content) -> some View {
        content
            .frame(maxHeight: isExpanded ? .infinity : 0)
            .opacity(isExpanded ? 1 : 0)
            .animation(.relatedTopicsExpand, value: isExpanded)
    }
}

// MARK: - Skeleton Loading View & Shimmer

/// Simple rectangular skeleton block that uses the shared shimmer effect.
struct SkeletonView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(.systemGray5))
            .shimmer()
    }
}

/// Shimmer animation modifier for skeleton placeholders.
private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1
    
    let accentColor: Color
    let backgroundColor: Color
    let speed: Double
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    let width = geometry.size.width
                    
                    // If motion is reduced or shimmer disabled, render static highlight
                    if !isActive || UIAccessibility.isReduceMotionEnabled {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        backgroundColor.opacity(0.7),
                                        accentColor.opacity(0.25),
                                        backgroundColor.opacity(0.7)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: width, height: geometry.size.height)
                    } else {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        backgroundColor.opacity(0.6),
                                        accentColor.opacity(0.30),
                                        Color.white.opacity(0.55),
                                        accentColor.opacity(0.30),
                                        backgroundColor.opacity(0.6)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: width * 1.8, height: geometry.size.height)
                            .offset(x: phase * width * 1.8)
                            .onAppear {
                                withAnimation(
                                    .linear(duration: speed)
                                        .repeatForever(autoreverses: false)
                                ) {
                                    phase = 1
                                }
                            }
                    }
                }
                .clipped()
            )
    }
}

// MARK: - Convenience View Modifiers

extension View {
    /// Apply message fade-in animation
    func messageFadeIn(delay: Double = 0) -> some View {
        modifier(MessageFadeInModifier(delay: delay))
    }
    
    /// Apply card press animation with haptic feedback and shadow
    func cardPressAnimation() -> some View {
        modifier(CardPressModifier())
    }
    
    /// Apply staggered fade-in for follow-up suggestions
    func staggeredFadeIn(index: Int, staggerDelay: Double = DesignSystem.followUpStaggerDelay) -> some View {
        modifier(StaggeredFadeInModifier(index: index, staggerDelay: staggerDelay))
    }
    
    /// Apply expand/collapse animation for related topics
    func expandCollapse(isExpanded: Binding<Bool>) -> some View {
        modifier(ExpandCollapseModifier(isExpanded: isExpanded))
    }
    
    /// Apply shimmer loading effect, accented with the design system color.
    func shimmer(
        accentColor: Color = DesignSystem.highlightColor,
        backgroundColor: Color = Color(.systemGray5),
        speed: Double = 1.4,
        isActive: Bool = true
    ) -> some View {
        modifier(
            ShimmerModifier(
                accentColor: accentColor,
                backgroundColor: backgroundColor,
                speed: speed,
                isActive: isActive
            )
        )
    }
}
