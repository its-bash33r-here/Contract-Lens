//
//  OnboardingFlowView.swift
//  lawgpt
//
//  Multi-step onboarding that appends user info to Google Sheets via Apps Script.
//

import SwiftUI
import StoreKit

enum OnboardingStep: Int, CaseIterable {
    case intro1
    case intro2
    case intro3
    case intro4
    case userType
    case name
    case gender
    case age
}

struct OnboardingFlowView: View {
    /// Legacy flag (no longer used for gating access to home, which is now based on subscription).
    /// Kept for backward compatibility and settings reset, but navigation is driven by RevenueCat.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var step: OnboardingStep = .intro1
    @State private var name: String = ""
    @State private var gender: String = ""
    @State private var age: String = ""
    @State private var selectedAge: Int = 25
    @State private var userType: String = ""
    
    @State private var isSubmitting = false
    @State private var submitError: String?
    @State private var animateContent = false
    @State private var animatePage2 = false
    @State private var animatePage3 = false
    @State private var animatePage4 = false
    @State private var isNameFieldFocused = false
    
    // MARK: - Computed Properties
    
    /// Validates that age is a valid number between 16 and 100
    private var isValidAge: Bool {
        let trimmedAge = age.trimmingCharacters(in: .whitespaces)
        guard !trimmedAge.isEmpty,
              let ageInt = Int(trimmedAge) else {
            return false
        }
        return ageInt >= 16 && ageInt <= 100
    }
    
    var body: some View {
        ZStack {
            // Solid white background per onboarding design update
            Color.white
                .ignoresSafeArea()
            
            content
        }
    }
    
    @ViewBuilder
    private var content: some View {
        switch step {
        case .intro1:
            introPage1
        case .intro2:
            introPage2
        case .intro3:
            introPage3
        case .intro4:
            introPage4
        case .userType:
            userTypePage
        case .name:
            namePage
        case .gender:
            genderPage
        case .age:
            agePage
        }
    }
    
    // MARK: - Intro Pages (1-4)
    
    private var introPage1: some View {
        ZStack(alignment: .bottom) {
            // Skip button - simulator only: grants Pro access, otherwise shows paywall
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        HapticManager.shared.lightImpact()
                        hasCompletedOnboarding = true
                    }) {
                        Text("Skip to Home")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 16)
                    .padding(.trailing, 20)
                }
                Spacer()
            }
            .zIndex(1)
            
            // Soft legal blue radial backdrop
            RadialGradient(
                colors: [
                    DesignSystem.highlightColor.opacity(0.16),
                    Color.white
                ],
                center: .center,
                startRadius: 40,
                endRadius: 420
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Branded app logo with gradient background
                AppLogoGradientView(size: 180)
                    .opacity(animateContent ? 1 : 0)
                    .scaleEffect(animateContent ? 1 : 0.9)
                    .offset(y: animateContent ? 0 : 8)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: animateContent)
                
                VStack(spacing: 12) {
                    Text("ClauseGuard")
                        .font(.system(size: 44, weight: .bold, design: .serif))
                        .foregroundColor(.primary)
                            .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 12)
                        .animation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.2), value: animateContent)
                    
                    Text("Spot red flags.\nNegotiate better.")
                        .font(.system(size: 18, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .lineSpacing(6)
                                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 14)
                        .animation(.spring(response: 0.65, dampingFraction: 0.85).delay(0.28), value: animateContent)
                        }
                .padding(.horizontal, 12)
                
                Spacer()
                }
            .padding(.horizontal, 32)
            
            // Primary call-to-action
            PremiumButton(title: "Get Started") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                    step = .intro2
                }
            }
            .scaleEffect(animateContent ? 1 : 0.9)
            .opacity(animateContent ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.82).delay(0.35), value: animateContent)
            .padding(.bottom, 32)
            .padding(.horizontal, 20)
        }
        .onAppear {
            withAnimation {
                animateContent = true
            }
        }
    }
    
    private var introPage2: some View {
        ZStack(alignment: .bottom) {
            RadialGradient(
                colors: [
                    DesignSystem.highlightColor.opacity(0.16),
                    Color.white
                ],
                center: .center,
                startRadius: 60,
                endRadius: 420
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                    OnboardingProgressIndicator(
                        currentIndex: step.rawValue,
                        totalSteps: OnboardingStep.allCases.count
                    )
                .padding(.top, 24)
                .opacity(0.9)
                
                Spacer()
                
                // Center badge icon
                ZStack {
                    Circle()
                        .fill(DesignSystem.highlightColor.opacity(0.18))
                        .frame(width: 136, height: 136)
                        .blur(radius: 24)
                        .opacity(animatePage2 ? 1 : 0)
                        .scaleEffect(animatePage2 ? 1 : 0.85)
                        .animation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.05), value: animatePage2)
                    
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 70, weight: .bold))
                        .foregroundStyle(DesignSystem.highlightColor)
                        .shadow(color: DesignSystem.highlightColor.opacity(0.35), radius: 18, x: 0, y: 8)
                        .opacity(animatePage2 ? 1 : 0)
                        .scaleEffect(animatePage2 ? 1 : 0.88)
                        .animation(.spring(response: 0.6, dampingFraction: 0.78).delay(0.12), value: animatePage2)
                }
                
                VStack(spacing: 12) {
                    Text("Verified Sources")
                        .font(.system(size: 32, weight: .bold, design: .serif))
                        .foregroundColor(.primary)
                        .opacity(animatePage2 ? 1 : 0)
                        .offset(y: animatePage2 ? 0 : 12)
                        .animation(.spring(response: 0.6, dampingFraction: 0.82).delay(0.2), value: animatePage2)
                            
                    Text("Every answer comes with citations you can tap to verify instantly.")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                                .lineSpacing(5)
                                .padding(.horizontal, 32)
                        .opacity(animatePage2 ? 1 : 0)
                        .offset(y: animatePage2 ? 0 : 14)
                        .animation(.spring(response: 0.62, dampingFraction: 0.85).delay(0.28), value: animatePage2)
                }
                
                Spacer()
                    }
            .padding(.horizontal, 28)
            
            PremiumButton(title: "Continue") {
                step = .intro3
            }
            .padding(.bottom, 32)
            .padding(.horizontal, 20)
            .scaleEffect(animatePage2 ? 1 : 0.94)
            .opacity(animatePage2 ? 1 : 0)
            .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.34), value: animatePage2)
        }
        .onAppear {
            withAnimation {
                animatePage2 = true
            }
        }
    }
    
    private var introPage3: some View {
        ZStack(alignment: .bottom) {
            RadialGradient(
                colors: [
                    Color.orange.opacity(0.15),
                    Color.white
                ],
                center: .center,
                startRadius: 60,
                endRadius: 420
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                    OnboardingProgressIndicator(
                        currentIndex: step.rawValue,
                        totalSteps: OnboardingStep.allCases.count
                    )
                .padding(.top, 24)
                .opacity(0.9)
                    
                Spacer()
                    
                // Center lightning icon
                            ZStack {
                                Circle()
                        .fill(Color.orange.opacity(0.16))
                        .frame(width: 136, height: 136)
                        .blur(radius: 24)
                        .opacity(animatePage3 ? 1 : 0)
                        .scaleEffect(animatePage3 ? 1 : 0.85)
                        .animation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.05), value: animatePage3)
                                
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 70, weight: .bold))
                        .foregroundStyle(Color.orange)
                        .shadow(color: Color.orange.opacity(0.35), radius: 18, x: 0, y: 8)
                        .opacity(animatePage3 ? 1 : 0)
                        .scaleEffect(animatePage3 ? 1 : 0.88)
                        .animation(.spring(response: 0.6, dampingFraction: 0.78).delay(0.12), value: animatePage3)
                }
                
            VStack(spacing: 12) {
                    Text("Fast & Focused")
                        .font(.system(size: 32, weight: .bold, design: .serif))
                        .foregroundColor(.primary)
                        .opacity(animatePage3 ? 1 : 0)
                        .offset(y: animatePage3 ? 0 : 12)
                        .animation(.spring(response: 0.6, dampingFraction: 0.82).delay(0.2), value: animatePage3)
                    
                    Text("Get concise answers with practical guidance — no endless scrolling.")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                                .lineSpacing(5)
                                .padding(.horizontal, 32)
                        .opacity(animatePage3 ? 1 : 0)
                        .offset(y: animatePage3 ? 0 : 14)
                        .animation(.spring(response: 0.62, dampingFraction: 0.85).delay(0.28), value: animatePage3)
                }
                
                Spacer()
                    }
            .padding(.horizontal, 28)
            
            PremiumButton(title: "Continue") {
                step = .intro4
            }
            .padding(.bottom, 32)
            .padding(.horizontal, 20)
            .scaleEffect(animatePage3 ? 1 : 0.94)
            .opacity(animatePage3 ? 1 : 0)
            .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.34), value: animatePage3)
        }
        .onAppear {
            withAnimation {
                animatePage3 = true
            }
        }
    }
    
    private var introPage4: some View {
        ZStack(alignment: .bottom) {
            RadialGradient(
                                            colors: [
                    Color.green.opacity(0.16),
                    Color.white
                ],
                center: .center,
                startRadius: 60,
                endRadius: 420
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                    OnboardingProgressIndicator(
                        currentIndex: step.rawValue,
                        totalSteps: OnboardingStep.allCases.count
                    )
                .padding(.top, 24)
                .opacity(0.9)
                    
                Spacer()
                    
                // Center shield-lock icon
                            ZStack {
                                Circle()
                        .fill(Color.green.opacity(0.16))
                        .frame(width: 136, height: 136)
                        .blur(radius: 24)
                        .opacity(animatePage4 ? 1 : 0)
                        .scaleEffect(animatePage4 ? 1 : 0.85)
                        .animation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.05), value: animatePage4)
                                    
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 70, weight: .bold))
                        .foregroundStyle(Color.green)
                        .shadow(color: Color.green.opacity(0.35), radius: 18, x: 0, y: 8)
                        .opacity(animatePage4 ? 1 : 0)
                        .scaleEffect(animatePage4 ? 1 : 0.88)
                        .animation(.spring(response: 0.6, dampingFraction: 0.78).delay(0.12), value: animatePage4)
                                }
                
            VStack(spacing: 12) {
                    Text("Built for Safety")
                        .font(.system(size: 32, weight: .bold, design: .serif))
                        .foregroundColor(.primary)
                        .opacity(animatePage4 ? 1 : 0)
                        .offset(y: animatePage4 ? 0 : 12)
                        .animation(.spring(response: 0.6, dampingFraction: 0.82).delay(0.2), value: animatePage4)
                    
                    Text("Informational only, with clear reminders for clinical judgment.")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .padding(.horizontal, 32)
                        .opacity(animatePage4 ? 1 : 0)
                        .offset(y: animatePage4 ? 0 : 14)
                        .animation(.spring(response: 0.62, dampingFraction: 0.85).delay(0.28), value: animatePage4)
                }
                
                Spacer()
            }
            .padding(.horizontal, 28)
            
            PremiumButton(title: "Continue") {
                    step = .userType
            }
            .padding(.bottom, 32)
            .padding(.horizontal, 20)
            .scaleEffect(animatePage4 ? 1 : 0.94)
            .opacity(animatePage4 ? 1 : 0)
            .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.34), value: animatePage4)
        }
        .onAppear {
            withAnimation {
                animatePage4 = true
            }
        }
    }
    
    // MARK: - User Type Page
    
    private var userTypePage: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                // Scrolling disabled for onboarding
            }
            .scrollDisabled(true)
            .overlay(
                VStack(spacing: 0) {
                    OnboardingProgressIndicator(
                        currentIndex: step.rawValue,
                        totalSteps: OnboardingStep.allCases.count
                    )
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                    
                    // Header Section - positioned at top
                    VStack(spacing: 16) {
                        Text("Tell us about yourself")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(Color.primary)
                            .tracking(0.5)
                        
                        Text("Help us personalize your experience by selecting what best describes you.")
                            .font(.system(size: 17, weight: .medium, design: .default))
                            .foregroundColor(Color.primary.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .tracking(0.3)
                            .lineSpacing(4)
                            .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 40)
            
                    // User Type Selection Section
                    VStack(spacing: 12) {
                        simpleRadioButton(
                            title: "Lawyer",
                            isSelected: userType == "lawyer",
                            action: { userType = "lawyer" }
                        )
                        simpleRadioButton(
                            title: "Paralegal",
                            isSelected: userType == "paralegal",
                            action: { userType = "paralegal" }
                        )
                        simpleRadioButton(
                            title: "Law Student",
                            isSelected: userType == "studying",
                            action: { userType = "studying" }
                        )
                        simpleRadioButton(
                            title: "Business Owner",
                            isSelected: userType == "business",
                            action: { userType = "business" }
                        )
                        simpleRadioButton(
                            title: "General Public",
                            isSelected: userType == "curious",
                            action: { userType = "curious" }
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    if let error = submitError, step == .userType {
                        errorText(error)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                    }
                    
                    Spacer()
                }
            )
            
            // Premium Continue Button - Fixed bottom position
            PremiumButton(title: "Continue") {
                guard !userType.isEmpty else {
                    submitError = "Please select an option to continue."
                    return
                }
                submitError = nil
                    step = .name
                }
            .disabled(userType.isEmpty)
            .opacity(userType.isEmpty ? 0.5 : 1.0)
            .padding(.bottom, 32)
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Name Page
    
    private var namePage: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                // Scrolling disabled for onboarding
            }
            .scrollDisabled(true)
            .overlay(
                VStack(spacing: 0) {
                    OnboardingProgressIndicator(
                        currentIndex: step.rawValue,
                        totalSteps: OnboardingStep.allCases.count
                    )
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                    
                    // Welcome Section with Icon - positioned at top
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.2),
                                                Color(red: 0.0, green: 0.38, blue: 0.85).opacity(0.15)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "person.fill")
                                    .font(.system(size: 36, weight: .semibold))
                                    .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0))
                            }
                            
                            Text("Let's get started")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(Color.primary)
                                .tracking(0.5)
                            
                            Text("We'd like to know a bit about you")
                                .font(.system(size: 17, weight: .medium, design: .default))
                                .foregroundColor(Color.primary.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .tracking(0.3)
                                .lineSpacing(4)
                        }
                    .padding(.bottom, 40)
                        
                        // Name Input Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("What is your name?")
                                .font(.system(size: 19, weight: .semibold, design: .default))
                                .foregroundColor(Color.primary)
                            
                        // Simple, clean text field
                        TextField("Enter your name", text: $name)
                            .font(.system(size: 17, weight: .regular, design: .default))
                            .foregroundColor(.primary)
                            .autocapitalization(.words)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 20)
                        
            if let error = submitError, step == .name {
                errorText(error)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
            }
                    
                    Spacer()
                }
            )
            
            // Premium Continue Button - Fixed bottom position
            PremiumButton(title: "Continue") {
                guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
                    submitError = "Please enter your name to continue."
                    return
                }
                submitError = nil
                step = .gender
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
            .padding(.bottom, 32)
            .padding(.horizontal, 20)
        }
        .task {
            // Request Apple's native review when landing on name page
            // Small delay to ensure the view is fully presented
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: windowScene)
            }
        }
    }
    
    
    // MARK: - Page 7: Gender
    
    private var genderPage: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                // Scrolling disabled for onboarding
            }
            .scrollDisabled(true)
            .overlay(
                VStack(spacing: 0) {
                    OnboardingProgressIndicator(
                        currentIndex: step.rawValue,
                        totalSteps: OnboardingStep.allCases.count
                    )
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                    
                    // Header Section with Icon - positioned at top
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.2),
                                            Color(red: 0.0, green: 0.38, blue: 0.85).opacity(0.15)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0))
                        }
                        
                            Text("Tell us about yourself")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(Color.primary)
                                .tracking(0.5)
                            
                            Text("Help us personalize your experience")
                                .font(.system(size: 17, weight: .medium, design: .default))
                                .foregroundColor(Color.primary.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .tracking(0.3)
                                .lineSpacing(4)
                        }
                    .padding(.bottom, 40)
                        
                        // Gender Selection Section
                        VStack(alignment: .leading, spacing: 16) {
                Text("What is your gender?")
                                .font(.system(size: 19, weight: .semibold, design: .default))
                    .foregroundColor(Color.primary)
                
                            VStack(spacing: 12) {
                                enhancedGenderButton(
                                    icon: "person.fill",
                                    title: "Male",
                                    isSelected: gender == "Male",
                                    action: { gender = "Male" }
                                )
                                enhancedGenderButton(
                                    icon: "person.fill",
                                    title: "Female",
                                    isSelected: gender == "Female",
                                    action: { gender = "Female" }
                                )
                                enhancedGenderButton(
                                    icon: "person.2.fill",
                                    title: "Non-binary",
                                    isSelected: gender == "Non-binary",
                                    action: { gender = "Non-binary" }
                                )
                                enhancedGenderButton(
                                    icon: "eye.slash.fill",
                                    title: "Prefer not to say",
                                    isSelected: gender == "Prefer not to say",
                                    action: { gender = "Prefer not to say" }
                                )
                            }
                            .padding(.horizontal, 2)
                        }
                    .padding(.horizontal, 20)
                        
            if let error = submitError, step == .gender {
                errorText(error)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
            }
                    
                    Spacer()
                }
            )
            
            // Premium Continue Button - Fixed bottom position
            PremiumButton(title: "Continue") {
                guard !gender.isEmpty else {
                    submitError = "Please select a gender to continue."
                    return
                }
                submitError = nil
                step = .age
            }
            .disabled(gender.isEmpty)
            .opacity(gender.isEmpty ? 0.5 : 1.0)
            .padding(.bottom, 32)
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Page 8: Age
    
    private var agePage: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                // Scrolling disabled for onboarding
            }
            .scrollDisabled(true)
            .overlay(
                VStack(spacing: 0) {
                    OnboardingProgressIndicator(
                        currentIndex: step.rawValue,
                        totalSteps: OnboardingStep.allCases.count
                    )
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                    
                    agePageHeader
                    agePageContent
                    
                    Spacer()
                }
            )
            
            agePageSubmitButton
        }
    }
    
    @ViewBuilder
    private var agePageHeader: some View {
                        VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.2),
                                            Color(red: 0.0, green: 0.38, blue: 0.85).opacity(0.15)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "calendar")
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0))
                        }
                        
                            Text("Final step")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(Color.primary)
                                .tracking(0.5)
                            
                Text("What is your age?")
                            .font(.system(size: 17, weight: .medium, design: .default))
                            .foregroundColor(Color.primary.opacity(0.85))
                                .multilineTextAlignment(.center)
                            .tracking(0.3)
                            .lineSpacing(4)
                        }
                    .padding(.bottom, 40)
    }
                    
    @ViewBuilder
    private var agePageContent: some View {
                    VStack(spacing: 36) {
            ageInputSection
            if let error = submitError, step == .age {
                errorText(error)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
            }
        }
    }
    
    @ViewBuilder
    private var ageInputSection: some View {
                        VStack(spacing: 24) {
            ageTextField
            agePicker
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private var ageTextField: some View {
                            VStack(spacing: 8) {
            ageInputField
            ageSuffixText
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 30)
        .background(ageTextFieldBackground)
        .overlay(ageTextFieldBorder)
        .shadow(color: ageTextFieldShadowColor, radius: age.isEmpty ? 0 : 20, x: 0, y: 0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: age.isEmpty)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isValidAge)
    }
    
    private var ageInputField: some View {
                                TextField("", text: $age)
                                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundColor(Color.primary)
                    .keyboardType(.numberPad)
                                    .autocorrectionDisabled()
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: 200)
                                    .onChange(of: age) { newValue in
                                        let filtered = newValue.filter { $0.isNumber }
                                        if filtered != newValue {
                                            age = filtered
                                        }
                                        if let ageInt = Int(filtered), ageInt >= 16 && ageInt <= 100 {
                                            selectedAge = ageInt
                                        }
                                    }
            .overlay(agePlaceholder)
    }
    
    @ViewBuilder
    private var agePlaceholder: some View {
                                            if age.isEmpty {
                                                Text("Age")
                                                    .font(.system(size: 64, weight: .bold, design: .rounded))
                                                    .foregroundColor(Color.primary.opacity(0.2))
                                                    .allowsHitTesting(false)
                                            }
                                        }
                                
    @ViewBuilder
    private var ageSuffixText: some View {
                                if !age.isEmpty {
                                    Text("years old")
                                        .font(.system(size: 18, weight: .medium, design: .default))
                                        .foregroundColor(Color.primary.opacity(0.6))
                                        .transition(.opacity.combined(with: .scale))
                                }
                            }
    
    private var ageTextFieldBackground: some View {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.1),
                                                Color.white.opacity(0.05)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
    }
    
    private var ageTextFieldBorder: some View {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(
                                        age.isEmpty ? Color.white.opacity(0.15) : 
                                        (isValidAge ? DesignSystem.highlightColor : Color.red.opacity(0.6)),
                                        lineWidth: age.isEmpty ? 1.5 : 2.5
                                    )
    }
    
    private var ageTextFieldShadowColor: Color {
        age.isEmpty ? Color.clear : 
        (isValidAge ? DesignSystem.highlightColor.opacity(0.4) : Color.red.opacity(0.3))
    }
    
    @ViewBuilder
    private var agePicker: some View {
                            VStack(spacing: 16) {
                                Text("Or select from picker")
                                    .font(.system(size: 15, weight: .medium, design: .default))
                                    .foregroundColor(Color.primary.opacity(0.6))
                                
                                Picker("Age", selection: $selectedAge) {
                                    ForEach(16...100, id: \.self) { ageValue in
                                        Text("\(ageValue)")
                                            .tag(ageValue)
                                            .foregroundColor(Color.primary)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(height: 180)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.white.opacity(0.05))
                                )
                                .onChange(of: selectedAge) { newValue in
                                    age = String(newValue)
                                }
                                .onAppear {
                                    if let ageInt = Int(age), ageInt >= 16 && ageInt <= 100 {
                                        selectedAge = ageInt
                                    } else if age.isEmpty {
                                        age = String(selectedAge)
                                    }
                                }
                            }
                        }
    
    private var agePageSubmitButton: some View {
            PremiumButton(title: isSubmitting ? "Starting..." : "Submit") {
                Task { await submitAndContinue() }
            }
            .disabled(isSubmitting || !isValidAge)
            .opacity(isSubmitting || !isValidAge ? 0.5 : 1.0)
            .padding(.bottom, 32)
            .padding(.horizontal, 20)
    }
    
    // MARK: - Submission
    
    private func submitAndContinue() async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            submitError = "Please enter your name to continue."
            step = .name
            return
        }
        guard !gender.isEmpty else {
            submitError = "Please select a gender to continue."
            step = .gender
            return
        }
        // Validate age is not empty
        guard !age.trimmingCharacters(in: .whitespaces).isEmpty else {
            submitError = "Please enter your age to continue."
            step = .age
            return
        }
        
        // Validate age is a valid number
        guard let ageInt = Int(age.trimmingCharacters(in: .whitespaces)) else {
            submitError = "Please enter a valid age (numbers only)."
            step = .age
            return
        }
        
        // Validate age is in valid range
        guard ageInt >= 16 && ageInt <= 100 else {
            submitError = "Please enter an age between 16 and 100."
            step = .age
            return
        }
        
        isSubmitting = true
        submitError = nil
        hasCompletedOnboarding = true
        isSubmitting = false
    }
    
    // MARK: - Helpers
    
    private var headerText: some View {
        VStack(spacing: 10) {
            Text("Tell us about yourself")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(Color.primary)
                .tracking(0.5)
            Text("Help us personalize your experience.")
                .font(.system(size: 18, weight: .medium, design: .default))
                .foregroundColor(Color.primary.opacity(0.9))
                .tracking(0.3)
                .lineSpacing(3)
        }
    }
    
    private func labelRow(system: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: system)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Color.primary)
            Text(text)
                .font(.title3.weight(.semibold))
                .foregroundColor(Color.primary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func labelRow(icon: AnyView, text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            icon
                .frame(width: 44, height: 44)
                .layoutPriority(0)
            
            Text(text)
                .font(.title3.weight(.semibold))
                .foregroundColor(Color.primary)
                .multilineTextAlignment(.leading)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func featureCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(Color.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(Color.primary.opacity(0.8))
            }
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func radioButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.selection()
            action()
        }) {
            radioButtonContent(title: title, isSelected: isSelected)
        }
    }
    
    @ViewBuilder
    private func radioButtonContent(title: String, isSelected: Bool) -> some View {
            HStack {
                Text(title)
                    .foregroundColor(Color.primary)
                Spacer()
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? .blue : .white.opacity(0.7))
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(radioButtonBorder(isSelected: isSelected))
        .shadow(color: radioButtonShadowColor(isSelected: isSelected), radius: isSelected ? 12 : 0, x: 0, y: 0)
        .shadow(color: radioButtonSecondaryShadowColor(isSelected: isSelected), radius: isSelected ? 20 : 0, x: 0, y: 0)
    }
    
    private func radioButtonBorder(isSelected: Bool) -> some View {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? Color(red: 0.0, green: 0.48, blue: 1.0) : Color.clear,
                        lineWidth: isSelected ? 2 : 0
                    )
    }
    
    private func radioButtonShadowColor(isSelected: Bool) -> Color {
        isSelected ? Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.6) : Color.clear
    }
    
    private func radioButtonSecondaryShadowColor(isSelected: Bool) -> Color {
        isSelected ? Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.4) : Color.clear
    }
    
    private func enhancedRadioButton(icon: String, title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon Container
                ZStack {
                    Circle()
                        .fill(
                            isSelected ?
                            LinearGradient(
                                colors: [
                                    DesignSystem.highlightColor,
                                    DesignSystem.legalBlueDark
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                }
                
                // Text Content
                Text(title)
                    .font(.system(size: 17, weight: .medium, design: .default))
                    .foregroundColor(Color.primary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
                
                // Selection Indicator
                ZStack {
                    Circle()
                        .fill(isSelected ? Color(red: 0.0, green: 0.48, blue: 1.0) : Color.clear)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.primary)
                    } else {
                        Circle()
                            .stroke(Color.white.opacity(0.4), lineWidth: 2)
                            .frame(width: 24, height: 24)
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isSelected ?
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.06),
                                Color.white.opacity(0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? Color(red: 0.0, green: 0.48, blue: 1.0) : Color(.separator).opacity(0.5),
                        lineWidth: isSelected ? 2.5 : 1
                    )
            )
                .shadow(
                color: isSelected ? DesignSystem.highlightColor.opacity(0.5) : Color.clear,
                radius: isSelected ? 16 : 0,
                x: 0,
                y: 0
            )
            .shadow(
                color: isSelected ? DesignSystem.highlightColor.opacity(0.3) : Color.clear,
                radius: isSelected ? 24 : 0,
                x: 0,
                y: 0
            )
            .scaleEffect(isSelected ? 1.01 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            .padding(.horizontal, isSelected ? 3 : 0)
            .padding(.vertical, isSelected ? 3 : 0)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func primaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(Color.primary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(isSubmitting)
        .opacity(isSubmitting ? 0.7 : 1.0)
    }
    
    private func errorText(_ text: String) -> some View {
        Text(text)
            .foregroundColor(.red)
            .font(.footnote)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func simpleRadioButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.selection()
            action()
        }) {
            HStack(spacing: 16) {
                // Text Content
                Text(title)
                    .font(.system(size: 17, weight: .medium, design: .default))
                    .foregroundColor(Color.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
                
                // Selection Indicator
                ZStack {
                    Circle()
                        .fill(isSelected ? DesignSystem.highlightColor : Color.clear)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Circle()
                            .stroke(Color(.separator).opacity(0.5), lineWidth: 2)
                            .frame(width: 24, height: 24)
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isSelected ?
                        LinearGradient(
                            colors: [
                                DesignSystem.highlightColor.opacity(0.16),
                                DesignSystem.legalBlueDark.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.06),
                                Color.white.opacity(0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? DesignSystem.highlightColor : Color(.separator).opacity(0.5),
                        lineWidth: isSelected ? 2.5 : 1
                    )
            )
            .shadow(
                color: isSelected ? DesignSystem.highlightColor.opacity(0.45) : Color.clear,
                radius: isSelected ? 16 : 0,
                x: 0,
                y: 0
            )
            .shadow(
                color: isSelected ? DesignSystem.highlightColor.opacity(0.3) : Color.clear,
                radius: isSelected ? 24 : 0,
                x: 0,
                y: 0
            )
            .scaleEffect(isSelected ? 1.01 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            .padding(.horizontal, isSelected ? 3 : 0)
            .padding(.vertical, isSelected ? 3 : 0)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Animated Feature Row Component
    
    struct AnimatedFeatureRow: View {
        let icon: String
        let iconColor: Color
        let text: String
        let delay: Double
        @State private var isVisible = false
        
        var body: some View {
            HStack(alignment: .top, spacing: 18) {
                // Icon Container with Pulse Animation
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    iconColor.opacity(0.3),
                                    iconColor.opacity(0.0)
                                ],
                                center: .center,
                                startRadius: 15,
                                endRadius: 35
                            )
                        )
                        .frame(width: 70, height: 70)
                        .opacity(isVisible ? 1 : 0)
                        .scaleEffect(isVisible ? 1 : 0.8)
                    
                    // Icon background
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            iconColor.opacity(0.4),
                                            iconColor.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: iconColor.opacity(0.3), radius: 12, x: 0, y: 4)
                    
                    // SF Symbol Icon
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(iconColor)
                        .scaleEffect(isVisible ? 1 : 0.5)
                        .rotationEffect(.degrees(isVisible ? 0 : -180))
                }
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.7)
                    .delay(delay),
                    value: isVisible
                )
                
                // Text Content
                Text(text)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.primary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(4)
                    .tracking(0.3)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(isVisible ? 1 : 0)
                    .offset(x: isVisible ? 0 : -20)
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.8)
                        .delay(delay + 0.1),
                        value: isVisible
                    )
                
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onAppear {
                isVisible = true
            }
        }
    }
    
    private func enhancedGenderButton(icon: String, title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.selection()
            action()
        }) {
            HStack(spacing: 16) {
                // Text Content
                Text(title)
                    .font(.system(size: 17, weight: .medium, design: .default))
                    .foregroundColor(Color.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
                
                // Selection Indicator
                ZStack {
                    Circle()
                        .fill(isSelected ? DesignSystem.highlightColor : Color.clear)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Circle()
                            .stroke(Color.white.opacity(0.4), lineWidth: 2)
                            .frame(width: 24, height: 24)
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isSelected ?
                        LinearGradient(
                            colors: [
                                DesignSystem.highlightColor.opacity(0.16),
                                DesignSystem.legalBlueDark.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.06),
                                Color.white.opacity(0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? DesignSystem.highlightColor : Color(.separator).opacity(0.5),
                        lineWidth: isSelected ? 2.5 : 1
                    )
            )
            .shadow(
                color: isSelected ? DesignSystem.highlightColor.opacity(0.45) : Color.clear,
                radius: isSelected ? 16 : 0,
                x: 0,
                y: 0
            )
            .shadow(
                color: isSelected ? DesignSystem.highlightColor.opacity(0.3) : Color.clear,
                radius: isSelected ? 24 : 0,
                x: 0,
                y: 0
            )
            .scaleEffect(isSelected ? 1.01 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            .padding(.horizontal, isSelected ? 3 : 0)
            .padding(.vertical, isSelected ? 3 : 0)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Enhanced Components

struct EnhancedFeatureRow: View {
    let icon: AnyView
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            // Icon with subtle background
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 56, height: 56)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                
                icon
                    .frame(width: 48, height: 48)
            }
            .layoutPriority(0)
            
            // Text - Beautiful Typography
            Text(text)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(Color.primary)
                .multilineTextAlignment(.leading)
                .lineSpacing(6)
                .tracking(0.3)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EnhancedFeatureCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            // Icon Container
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            .frame(width: 64, height: 64)
            
            // Text Content - Beautiful Typography
            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.primary)
                    .tracking(0.2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(subtitle)
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundColor(Color.primary.opacity(0.85))
                    .tracking(0.2)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            }
            
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Animated Feature Card Component

struct AnimatedFeatureCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let delay: Double
    @State private var isVisible = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            // Icon Container with Enhanced Animation
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                iconColor.opacity(0.4),
                                iconColor.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 45
                        )
                    )
                    .frame(width: 80, height: 80)
                    .opacity(isVisible ? 1 : 0)
                    .scaleEffect(isVisible ? 1 : 0.5)
                
                // Icon background with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        iconColor.opacity(0.5),
                                        iconColor.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: iconColor.opacity(0.4), radius: 16, x: 0, y: 6)
                
                // Icon with rotation animation
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(iconColor)
                    .scaleEffect(isVisible ? 1 : 0.3)
                    .rotationEffect(.degrees(isVisible ? 0 : 360))
            }
            .frame(width: 72, height: 72)
            .animation(
                .spring(response: 0.6, dampingFraction: 0.7)
                .delay(delay),
                value: isVisible
            )
            
            // Text Content with Slide Animation
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(Color.primary)
                    .tracking(0.3)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(subtitle)
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundColor(Color.primary.opacity(0.8))
                    .tracking(0.2)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(5)
            }
            .opacity(isVisible ? 1 : 0)
            .offset(x: isVisible ? 0 : -30)
            .animation(
                .spring(response: 0.7, dampingFraction: 0.8)
                .delay(delay + 0.15),
                value: isVisible
            )
            
            Spacer(minLength: 0)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 8)
        .shadow(color: iconColor.opacity(0.1), radius: 30, x: 0, y: 12)
        .scaleEffect(isVisible ? 1 : 0.9)
        .opacity(isVisible ? 1 : 0)
        .animation(
            .spring(response: 0.6, dampingFraction: 0.75)
            .delay(delay),
            value: isVisible
        )
        .onAppear {
            isVisible = true
        }
    }
}

// MARK: - Simple Feature Row Component

struct SimpleFeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            // Simple Icon
            Image(systemName: icon)
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(iconColor.opacity(0.15))
                )
            
            // Text Content
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Color.primary)
                    .tracking(0.2)
                
                Text(description)
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundColor(Color.primary.opacity(0.75))
                    .tracking(0.2)
                    .lineSpacing(4)
            }
            
            Spacer()
        }
    }
}

struct PremiumButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            action()
        }) {
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .tracking(0.5)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignSystem.highlightColor, // Deep navy blue
                                    DesignSystem.legalBlueDark  // Darker navy blue
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        )
                )
                .shadow(color: DesignSystem.highlightColor.opacity(0.45), radius: 16, x: 0, y: 8)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
    }
}

/// Top progress indicator for onboarding steps (dots + active pill)
struct OnboardingProgressIndicator: View {
    let currentIndex: Int
    let totalSteps: Int
    
    private var legalGradient: LinearGradient {
        LinearGradient(
            colors: [
                DesignSystem.highlightColor,
                DesignSystem.legalBlueDark
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                if index == currentIndex {
                    Capsule()
                        .fill(legalGradient)
                        .frame(width: 26, height: 8)
                        .shadow(color: DesignSystem.highlightColor.opacity(0.4), radius: 4, x: 0, y: 2)
                } else if index < currentIndex {
                    Circle()
                        .fill(legalGradient)
                        .frame(width: 8, height: 8)
                } else {
                    Circle()
                        .fill(Color(.systemGray4))
                        .frame(width: 8, height: 8)
                }
            }
        }
    }
}

// MARK: - New Redesigned Components

struct FeatureCard: View {
    let icon: AnyView
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon Container
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                
                icon
                    .frame(width: 56, height: 56)
            }
            .frame(width: 64, height: 64)
            
            // Text
            Text(text)
                .font(.title3.weight(.semibold))
                .foregroundColor(Color.primary)
                .multilineTextAlignment(.leading)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
    }
}

struct TestimonialCard: View {
    var body: some View {
        VStack(spacing: 12) {
            // Stars
            HStack(spacing: 5) {
                ForEach(0..<5) { _ in
                    Image(systemName: "star.fill")
                        .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                        .font(.system(size: 16))
                        .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.4), radius: 3)
                }
            }
            
            // Quote
            Text("\"I've used several other legal AI apps and they don't even come close to the clarity and protection that ClauseGuard provides.\"")
                .font(.subheadline)
                .italic()
                .multilineTextAlignment(.center)
                .foregroundColor(Color.primary.opacity(0.9))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
    }
}

struct EnhancedButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    LinearGradient(
                        colors: [
                            DesignSystem.highlightColor, // Deep navy blue
                            DesignSystem.legalBlueDark  // Darker navy blue
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: DesignSystem.highlightColor.opacity(0.4), radius: 16, x: 0, y: 8)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - Custom Icon Views

struct LaurelWreathIcon: View {
    var body: some View {
        ZStack {
            // Left branch
            Path { path in
                path.move(to: CGPoint(x: 10, y: 20))
                path.addCurve(to: CGPoint(x: 20, y: 40), control1: CGPoint(x: 12, y: 25), control2: CGPoint(x: 18, y: 32))
                path.addCurve(to: CGPoint(x: 15, y: 50), control1: CGPoint(x: 22, y: 45), control2: CGPoint(x: 18, y: 48))
            }
            .stroke(Color.white, lineWidth: 2.5)
            
            // Right branch
            Path { path in
                path.move(to: CGPoint(x: 90, y: 20))
                path.addCurve(to: CGPoint(x: 80, y: 40), control1: CGPoint(x: 88, y: 25), control2: CGPoint(x: 82, y: 32))
                path.addCurve(to: CGPoint(x: 85, y: 50), control1: CGPoint(x: 78, y: 45), control2: CGPoint(x: 82, y: 48))
            }
            .stroke(Color.white, lineWidth: 2.5)
            
            // Leaves on left
            Ellipse()
                .foregroundColor(Color.white)
                .frame(width: 4, height: 8)
                .position(x: 18, y: 28)
                .rotationEffect(.degrees(-25))
            
            Ellipse()
                .foregroundColor(Color.white)
                .frame(width: 4, height: 8)
                .position(x: 22, y: 36)
                .rotationEffect(.degrees(15))
            
            // Leaves on right
            Ellipse()
                .foregroundColor(Color.white)
                .frame(width: 4, height: 8)
                .position(x: 82, y: 28)
                .rotationEffect(.degrees(25))
            
            Ellipse()
                .foregroundColor(Color.white)
                .frame(width: 4, height: 8)
                .position(x: 78, y: 36)
                .rotationEffect(.degrees(-15))
            
            // Center ribbon/bow
            Path { path in
                path.move(to: CGPoint(x: 40, y: 50))
                path.addLine(to: CGPoint(x: 60, y: 50))
            }
            .stroke(Color.white, lineWidth: 2)
        }
        .frame(width: 100, height: 70)
        .scaleEffect(0.6)
    }
}

struct CaduceusIcon: View {
    var body: some View {
        ZStack {
            // Central staff/rod
            Rectangle()
                .fill(Color.white)
                .frame(width: 3.5, height: 65)
                .position(x: 50, y: 47.5)
            
            // Left wing
            Path { path in
                path.move(to: CGPoint(x: 50, y: 12))
                path.addCurve(to: CGPoint(x: 32, y: 22), control1: CGPoint(x: 40, y: 16), control2: CGPoint(x: 35, y: 19))
                path.addCurve(to: CGPoint(x: 25, y: 18), control1: CGPoint(x: 29, y: 20), control2: CGPoint(x: 27, y: 19))
                path.addCurve(to: CGPoint(x: 50, y: 12), control1: CGPoint(x: 35, y: 14), control2: CGPoint(x: 42, y: 12))
            }
            .stroke(Color.white, lineWidth: 2.5)
            
            // Right wing
            Path { path in
                path.move(to: CGPoint(x: 50, y: 12))
                path.addCurve(to: CGPoint(x: 68, y: 22), control1: CGPoint(x: 60, y: 16), control2: CGPoint(x: 65, y: 19))
                path.addCurve(to: CGPoint(x: 75, y: 18), control1: CGPoint(x: 71, y: 20), control2: CGPoint(x: 73, y: 19))
                path.addCurve(to: CGPoint(x: 50, y: 12), control1: CGPoint(x: 65, y: 14), control2: CGPoint(x: 58, y: 12))
            }
            .stroke(Color.white, lineWidth: 2.5)
            
            // Left snake (winding around staff)
            Path { path in
                path.move(to: CGPoint(x: 50, y: 20))
                path.addCurve(to: CGPoint(x: 42, y: 30), control1: CGPoint(x: 46, y: 24), control2: CGPoint(x: 44, y: 27))
                path.addCurve(to: CGPoint(x: 50, y: 40), control1: CGPoint(x: 40, y: 33), control2: CGPoint(x: 45, y: 36))
                path.addCurve(to: CGPoint(x: 42, y: 50), control1: CGPoint(x: 46, y: 44), control2: CGPoint(x: 44, y: 47))
                path.addCurve(to: CGPoint(x: 50, y: 60), control1: CGPoint(x: 40, y: 53), control2: CGPoint(x: 45, y: 56))
                path.addCurve(to: CGPoint(x: 50, y: 72), control1: CGPoint(x: 42, y: 64), control2: CGPoint(x: 46, y: 68))
            }
            .stroke(Color.white, lineWidth: 2.5)
            
            // Right snake (winding opposite direction)
            Path { path in
                path.move(to: CGPoint(x: 50, y: 20))
                path.addCurve(to: CGPoint(x: 58, y: 30), control1: CGPoint(x: 54, y: 24), control2: CGPoint(x: 56, y: 27))
                path.addCurve(to: CGPoint(x: 50, y: 40), control1: CGPoint(x: 60, y: 33), control2: CGPoint(x: 55, y: 36))
                path.addCurve(to: CGPoint(x: 58, y: 50), control1: CGPoint(x: 54, y: 44), control2: CGPoint(x: 56, y: 47))
                path.addCurve(to: CGPoint(x: 50, y: 60), control1: CGPoint(x: 60, y: 53), control2: CGPoint(x: 55, y: 56))
                path.addCurve(to: CGPoint(x: 50, y: 72), control1: CGPoint(x: 58, y: 64), control2: CGPoint(x: 54, y: 68))
            }
            .stroke(Color.white, lineWidth: 2.5)
            
            // Snake heads
            Ellipse()
                .foregroundColor(Color.white)
                .frame(width: 7, height: 10)
                .position(x: 47, y: 76)
                .rotationEffect(.degrees(-15))
            
            Ellipse()
                .foregroundColor(Color.white)
                .frame(width: 7, height: 10)
                .position(x: 53, y: 76)
                .rotationEffect(.degrees(15))
        }
        .frame(width: 100, height: 85)
        .scaleEffect(0.6)
    }
}

struct GlobeIcon: View {
    var body: some View {
        ZStack {
            // Main circle outline
            Circle()
                .stroke(Color.white, lineWidth: 2.5)
                .frame(width: 75, height: 75)
            
            // Horizontal latitude lines
            Ellipse()
                .stroke(Color.white.opacity(0.7), lineWidth: 1.8)
                .frame(width: 75, height: 20)
                .offset(y: -15)
            
            Ellipse()
                .stroke(Color.white.opacity(0.7), lineWidth: 1.8)
                .frame(width: 75, height: 20)
            
            Ellipse()
                .stroke(Color.white.opacity(0.7), lineWidth: 1.8)
                .frame(width: 75, height: 20)
                .offset(y: 15)
            
            // Vertical longitude lines
            Path { path in
                path.move(to: CGPoint(x: 50, y: 12.5))
                path.addLine(to: CGPoint(x: 50, y: 87.5))
            }
            .stroke(Color.white.opacity(0.7), lineWidth: 1.8)
            
            Path { path in
                path.move(to: CGPoint(x: 50, y: 12.5))
                path.addCurve(to: CGPoint(x: 50, y: 87.5), control1: CGPoint(x: 65, y: 35), control2: CGPoint(x: 65, y: 65))
            }
            .stroke(Color.white.opacity(0.7), lineWidth: 1.8)
            
            Path { path in
                path.move(to: CGPoint(x: 50, y: 12.5))
                path.addCurve(to: CGPoint(x: 50, y: 87.5), control1: CGPoint(x: 35, y: 35), control2: CGPoint(x: 35, y: 65))
            }
            .stroke(Color.white.opacity(0.7), lineWidth: 1.8)
            
            // Grid overlay pattern
            Path { path in
                path.move(to: CGPoint(x: 20, y: 30))
                path.addCurve(to: CGPoint(x: 80, y: 30), control1: CGPoint(x: 40, y: 32), control2: CGPoint(x: 60, y: 28))
            }
            .stroke(Color.white.opacity(0.5), lineWidth: 1.2)
            
            Path { path in
                path.move(to: CGPoint(x: 20, y: 50))
                path.addCurve(to: CGPoint(x: 80, y: 50), control1: CGPoint(x: 40, y: 52), control2: CGPoint(x: 60, y: 48))
            }
            .stroke(Color.white.opacity(0.5), lineWidth: 1.2)
            
            Path { path in
                path.move(to: CGPoint(x: 20, y: 70))
                path.addCurve(to: CGPoint(x: 80, y: 70), control1: CGPoint(x: 40, y: 72), control2: CGPoint(x: 60, y: 68))
            }
            .stroke(Color.white.opacity(0.5), lineWidth: 1.2)
        }
        .frame(width: 100, height: 100)
        .scaleEffect(0.6)
    }
}

struct PillBottleProhibitedIcon: View {
    var body: some View {
        ZStack {
            // Legal blue circle background
            Circle()
                .foregroundColor(DesignSystem.highlightColor) // Deep navy blue
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2.5)
                )
                .frame(width: 85, height: 85)
            
            // Pill bottle body
            RoundedRectangle(cornerRadius: 2)
                .foregroundColor(Color.white)
                .frame(width: 28, height: 32)
                .offset(y: 3)
            
            // Bottle neck
            RoundedRectangle(cornerRadius: 1)
                .foregroundColor(Color.white)
                .frame(width: 14, height: 7)
                .offset(y: -11)
            
            // Bottle cap
            RoundedRectangle(cornerRadius: 1)
                .foregroundColor(Color.white)
                .frame(width: 18, height: 5)
                .offset(y: -15.5)
            
            // Pills inside (represented as small white dots)
            Circle()
                .foregroundColor(Color.white.opacity(0.9))
                .frame(width: 4, height: 4)
                .offset(x: -7, y: -4)
            
            Circle()
                .foregroundColor(Color.white.opacity(0.9))
                .frame(width: 4, height: 4)
                .offset(y: -6)
            
            Circle()
                .foregroundColor(Color.white.opacity(0.9))
                .frame(width: 4, height: 4)
                .offset(x: 7, y: -4)
            
            Circle()
                .foregroundColor(Color.white.opacity(0.9))
                .frame(width: 4, height: 4)
                .offset(x: -4, y: 2)
            
            Circle()
                .foregroundColor(Color.white.opacity(0.9))
                .frame(width: 4, height: 4)
                .offset(x: 4, y: 4)
            
            Circle()
                .foregroundColor(Color.white.opacity(0.9))
                .frame(width: 4, height: 4)
                .offset(y: 7)
            
            // Diagonal prohibition line (white outer, legal blue inner)
            Path { path in
                path.move(to: CGPoint(x: 22, y: 22))
                path.addLine(to: CGPoint(x: 78, y: 78))
            }
            .stroke(Color.white, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
            
            Path { path in
                path.move(to: CGPoint(x: 22, y: 22))
                path.addLine(to: CGPoint(x: 78, y: 78))
            }
            .stroke(DesignSystem.highlightColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
        .frame(width: 100, height: 100)
        .scaleEffect(0.6)
    }
}

