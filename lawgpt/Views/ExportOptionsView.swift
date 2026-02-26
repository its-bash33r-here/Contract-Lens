//
//  ExportOptionsView.swift
//  lawgpt
//
//  Created by Bash33r on 01/12/25.
//

import SwiftUI
import UniformTypeIdentifiers

/// View for selecting export format and sharing
struct ExportOptionsView: View {
    let message: Message?
    let conversation: Conversation?
    let messages: [Message]?
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: ExportFormat = .pdf
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var showShareSheet = false
    @State private var exportedURL: URL?
    
    private let exportService = ExportService()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Export Format") {
                    Picker("Format", selection: $selectedFormat) {
                        Label("PDF", systemImage: "doc.fill").tag(ExportFormat.pdf)
                        Label("Markdown", systemImage: "doc.text.fill").tag(ExportFormat.markdown)
                        Label("Plain Text", systemImage: "text.alignleft").tag(ExportFormat.plainText)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section {
                    Button(action: {
                        Task {
                            await performExport()
                        }
                    }) {
                        HStack {
                            if isExporting {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text(isExporting ? "Exporting..." : "Export")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isExporting)
                    
                    if let error = exportError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Section("Preview") {
                    if let message = message {
                        Text(message.content ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(5)
                    } else if let conversation = conversation {
                        Text(conversation.title ?? "Conversation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportedURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }
    
    private func performExport() async {
        isExporting = true
        exportError = nil
        
        do {
            let url: URL
            
            if let message = message {
                url = try await Task {
                    try exportService.exportMessage(message, format: selectedFormat)
                }.value
            } else if let conversation = conversation, let messages = messages {
                url = try await Task {
                    try exportService.exportConversation(conversation, messages: messages, format: selectedFormat)
                }.value
            } else {
                exportError = "No content to export"
                isExporting = false
                return
            }
            
            exportedURL = url
            HapticManager.shared.exportCompleted()
            showShareSheet = true
        } catch {
            exportError = "Export failed: \(error.localizedDescription)"
            HapticManager.shared.errorOccurred()
        }
        
        isExporting = false
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    ExportOptionsView(
        message: nil,
        conversation: nil,
        messages: nil
    )
}
