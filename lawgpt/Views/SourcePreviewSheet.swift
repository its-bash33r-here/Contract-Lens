//
//  SourcePreviewSheet.swift
//  lawgpt
//
//  Created by Bash33r on 01/12/25.
//

import SwiftUI
import SafariServices

/// Sheet view for previewing a source before opening
struct SourcePreviewSheet: View {
    let source: Source
    @Binding var isPresented: Bool
    @State private var showSafari = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with favicon and domain
                HStack(spacing: 12) {
                    AsyncImage(url: source.faviconURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Image(systemName: "globe")
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(source.domain)
                            .font(DesignSystem.secondaryBodyFont())
                            .foregroundColor(.secondary)
                        
                        Text(source.title)
                            .font(DesignSystem.heading3Font())
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Snippet/Preview
                if let snippet = source.snippet, !snippet.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(DesignSystem.captionFont())
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        Text(snippet)
                            .font(DesignSystem.bodyFont())
                            .foregroundColor(.primary)
                            .lineLimit(5)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
                
                // URL
                VStack(alignment: .leading, spacing: 8) {
                    Text("URL")
                        .font(DesignSystem.captionFont())
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    if let url = URL(string: source.url) {
                        Link(destination: url) {
                            Text(source.url)
                                .font(DesignSystem.captionFont())
                                .foregroundColor(.legalAccent)
                                .lineLimit(3)
                                .underline()
                        }
                    } else {
                        Text(source.url)
                            .font(DesignSystem.captionFont())
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                
                Spacer()
                
                // Open button
                Button(action: {
                    showSafari = true
                }) {
                    HStack {
                        Image(systemName: "safari")
                        Text("Open Source")
                    }
                    .font(DesignSystem.heading3Font())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44) // Minimum touch target
                    .padding()
                    .background(Color.legalAccent)
                    .cornerRadius(12)
                }
                .accessibilityLabel("Open source in Safari")
                .accessibilityHint("Opens the source website in Safari")
                .padding()
            }
            .navigationTitle("Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showSafari) {
                if let url = URL(string: source.url) {
                    SafariView(url: url)
                } else {
                    // Fallback view if URL is invalid
                    VStack {
                        Text("Invalid URL")
                            .font(.headline)
                            .padding()
                        Text("The source URL could not be opened.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Button("Close") {
                            showSafari = false
                        }
                        .padding()
                    }
                }
            }
        }
    }
}

// MARK: - Safari View Controller Wrapper
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = true
        
        let safariVC = SFSafariViewController(url: url, configuration: config)
        safariVC.preferredControlTintColor = .systemBlue
        return safariVC
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Preview
#Preview {
    SourcePreviewSheet(
        source: Source(
            title: "Diabetes Symptoms and Causes",
            url: "https://www.mayoclinic.org/diseases-conditions/diabetes/symptoms-causes/syc-20371444",
            snippet: "Diabetes symptoms vary depending on how much your blood sugar is elevated. Some people, especially those with prediabetes or type 2 diabetes, may sometimes not experience symptoms.",
            favicon: nil
        ),
        isPresented: .constant(true)
    )
}
