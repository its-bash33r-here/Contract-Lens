//
//  ImagePreviewSheet.swift
//  lawgpt
//
//  Created by Bash33r on 01/12/25.
//

import SwiftUI

/// Sheet for previewing and annotating images before sending
struct ImagePreviewSheet: View {
    let image: UIImage
    @Binding var isPresented: Bool
    let onSend: () -> Void
    
    @State private var annotationMode = false
    @State private var showAnalysis = false
    @State private var isAnalyzing = false
    @State private var analysisResult: String?
    @State private var analysisConfidence: Double = 0.0
    
    private let imageAnalysisService = ImageAnalysisService()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Image preview
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 400)
                    .background(Color(.systemGray6))
                
                // Analysis button
                Button(action: {
                    Task {
                        await analyzeImage()
                    }
                }) {
                    HStack {
                        if isAnalyzing {
                            ProgressView()
                                .padding(.trailing, 8)
                        }
                        Text(isAnalyzing ? "Analyzing..." : "Analyze Image")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.legalAccent)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isAnalyzing)
                .padding()
                
                // Analysis results
                if let analysis = analysisResult {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Analysis Results")
                                    .font(DesignSystem.heading3Font())
                                
                                Spacer()
                                
                                // Confidence indicator
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.shield")
                                    Text("\(Int(analysisConfidence * 100))% confidence")
                                        .font(DesignSystem.captionFont())
                                }
                                .foregroundColor(.secondary)
                            }
                            
                            Text(analysis)
                                .font(DesignSystem.bodyFont())
                                .foregroundColor(.primary)
                            
                            // Legal disclaimer
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.legalWarning)
                                Text("This analysis is for informational purposes only and should not replace professional legal advice.")
                                    .font(DesignSystem.captionFont())
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.legalWarning.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .padding()
                    }
                    .frame(maxHeight: 200)
                }
                
                Spacer()
            }
            .navigationTitle("Image Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send") {
                        HapticManager.shared.messageSent()
                        onSend()
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func analyzeImage() async {
        isAnalyzing = true
        analysisResult = nil
        
        let (analysis, confidence, _) = await imageAnalysisService.analyzeImage(image)
        
        analysisResult = analysis
        analysisConfidence = confidence
        isAnalyzing = false
        showAnalysis = true
    }
}

// MARK: - Preview

#Preview {
    ImagePreviewSheet(
        image: UIImage(systemName: "photo")!,
        isPresented: .constant(true),
        onSend: {}
    )
}
