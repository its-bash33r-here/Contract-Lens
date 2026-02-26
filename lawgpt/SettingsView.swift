//
//  SettingsView.swift
//  lawgpt
//
//  Created by Bash33r on 01/12/25.
//

import SwiftUI
import SafariServices

struct SettingsView: View {
    @State private var showAbout = false
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var safariURL: URL?
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showResetOnboardingAlert = false
    
    var body: some View {
        List {
            appInfoSection
            simulatorDebugSection
            appearanceSection
            legalSupportSection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(
            isPresented: Binding(
                get: { safariURL != nil },
                set: { if !$0 { safariURL = nil } }
            )
        ) {
            if let url = safariURL {
                InAppSafariView(url: url)
            } else {
                Text("") // Fallback
            }
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        .alert("Reset Onboarding", isPresented: $showResetOnboardingAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                hasCompletedOnboarding = false
                HapticManager.shared.success()
            }
        } message: {
            Text("This will reset your onboarding flow. You'll need to complete it again the next time you open the app.")
        }
    }
    
    @ViewBuilder
    private var appInfoSection: some View {
            Section {
                Button(action: { showAbout = true }) {
                    HStack(spacing: 16) {
                        AppLogoGradientView(size: 60, cornerRadius: 16)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("ClauseGuard")
                                .font(DesignSystem.heading3Font())

                            Text("AI Contract Lawyer")
                                .font(DesignSystem.secondaryBodyFont())
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
        }
            }

    @ViewBuilder
    private var appearanceSection: some View {
            Section("Appearance") {
                HStack {
                    Text("Theme")
                        .foregroundColor(.primary)

                    Spacer()

                    Picker("Theme", selection: $themeManager.currentTheme) {
                        ForEach(Theme.allCases) { theme in
                            Text(theme.rawValue)
                                .tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
                }
            }

    @ViewBuilder
    private var legalSupportSection: some View {
            Section("Legal & Support") {
                // Privacy Policy (in-app)
                Button {
                    openInApp("https://docs.google.com/document/d/1G_0NB959L_G3i8kEGm3UZ6xgVl8VdgCFFJU9nJeLCVc/view?usp=sharing")
                } label: {
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        Text("Privacy Policy")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Terms of Service (in-app)
                Button {
                    openInApp("https://docs.google.com/document/d/10Zv5BtMZmp0UGT7NdhRgtRV3ufsW5E2GhOCnq2XL838/view?usp=sharing")
                } label: {
                    HStack {
                        Image(systemName: "doc.richtext")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        Text("Terms of Service")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Contact (in-app)
                Button {
                    openInApp("https://tally.so/r/mBrqLe")
                } label: {
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        Text("Contact Support")
                            .foregroundColor(.primary)
                        
                        Spacer()
                            
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    }
                }
            }
            
    @ViewBuilder
    private var simulatorDebugSection: some View {
#if targetEnvironment(simulator)
            Section("Debug") {
                Button(action: {
                    HapticManager.shared.lightImpact()
                    showResetOnboardingAlert = true
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise.circle")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        Text("Reset Onboarding")
                            .foregroundColor(.primary)
                    }
                }
        }
#endif
    }
    
    // MARK: - Actions
    
    private func openInApp(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        safariURL = url
    }
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Source Link Row
struct SourceLinkRow: View {
    let icon: String
    let title: String
    let url: String
    
    var body: some View {
        if let url = URL(string: url) {
            Link(destination: url) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    Text(title)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } else {
            // Fallback if URL is invalid
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.gray)
                    .frame(width: 24)
                
                Text(title)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
    }
}

// MARK: - About View
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                    VStack(spacing: 24) {
                    // App logo
                    AppLogoGradientView(size: 110, cornerRadius: 26)
                        .padding(.top, 20)
                    
                    Text("ClauseGuard")
                        .font(DesignSystem.heading1Font())
                    
                    Text("Your AI Contract Lawyer")
                        .font(DesignSystem.heading3Font())
                        .foregroundColor(.secondary)
                    
                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(
                            icon: "checkmark.shield",
                            title: "Trusted Sources",
                            description: "Get information from authoritative legal sources like statutes, case law, regulations, and legal databases."
                        )
                        
                        FeatureRow(
                            icon: "link",
                            title: "Source Citations",
                            description: "Every answer includes citations so you can verify and explore the original sources."
                        )
                        
                        FeatureRow(
                            icon: "bubble.left.and.bubble.right",
                            title: "Conversational",
                            description: "Ask follow-up questions and have natural conversations about health topics."
                        )
                        
                        FeatureRow(
                            icon: "star",
                            title: "Save & Bookmark",
                            description: "Bookmark important conversations for quick reference later."
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                    // Disclaimer
                    VStack(spacing: 12) {
                        Text("Important Notice")
                            .font(DesignSystem.heading3Font())
                        
                            Text("ClauseGuard is designed to provide general legal information and should not be used as a substitute for professional legal advice. Always consult a licensed attorney before signing any agreement. This does not create an attorney-client relationship.")
                            .font(DesignSystem.captionFont())
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(20)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DesignSystem.heading3Font())
                
                Text(description)
                    .font(DesignSystem.secondaryBodyFont())
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - In-app Safari View
struct InAppSafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        return SFSafariViewController(url: url, configuration: config)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(ThemeManager.shared)
    }
}
