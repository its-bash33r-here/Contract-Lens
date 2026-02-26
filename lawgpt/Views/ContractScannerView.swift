//
//  ContractScannerView.swift
//  lawgpt
//
//  ClauseGuard — AI-powered Red Flag Scanner for contracts.
//  Full flow: Input (paste / camera / PDF) → Loading → Results dashboard
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ContractScannerView: View {
    @StateObject private var viewModel = ContractScannerViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showImagePicker    = false
    @State private var showCameraPicker   = false
    @State private var showDocumentPicker = false
    @State private var capturedImage: UIImage? = nil
    @State private var scanIconRotation: Double = 0

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            // Use a switch over the state to drive the full-view transitions
            Group {
                switch viewModel.scanState {
                case .idle:
                    inputView
                        .transition(.opacity)

                case .loading(let status):
                    loadingView(status: status)
                        .transition(.opacity)

                case .result(let result):
                    ResultsDashboardView(
                        result: result,
                        onReset: { withAnimation { viewModel.reset() } }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))

                case .error(let msg):
                    errorView(message: msg)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: stateTag)
        }
        // Image from photo library
        .sheet(isPresented: $showImagePicker) {
            PhotoPickerView(selectedImage: $capturedImage)
                .ignoresSafeArea()
        }
        // Image from camera
        .fullScreenCover(isPresented: $showCameraPicker) {
            CameraPickerView(selectedImage: $capturedImage)
                .ignoresSafeArea()
        }
        // PDF document picker
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView { url in
                Task { await viewModel.analyzePDF(url: url) }
            }
        }
        .onChange(of: capturedImage) { img in
            guard let img else { return }
            capturedImage = nil
            Task { await viewModel.analyzeImage(img) }
        }
    }

    // Unique tag for animation
    private var stateTag: Int {
        switch viewModel.scanState {
        case .idle:    return 0
        case .loading: return 1
        case .result:  return 2
        case .error:   return 3
        }
    }

    // MARK: - Input View

    private var inputView: some View {
        ScrollView {
            VStack(spacing: 28) {
                inputHeader
                inputMethodButtons

                HStack {
                    Rectangle().frame(height: 0.5).foregroundColor(.secondary.opacity(0.3))
                    Text("or paste below")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize()
                    Rectangle().frame(height: 0.5).foregroundColor(.secondary.opacity(0.3))
                }
                .padding(.horizontal, 24)

                contractTextEditor
                scanButton

                Text("For informational purposes only — not a substitute for professional legal advice.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Input sub-views

    private var inputHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(DesignSystem.accentColor)
                    Text("Contract Scanner")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                }
                Text("Upload or paste your contract.\nGet instant AI red-flag analysis.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.top, 4)
        }
    }

    private var inputMethodButtons: some View {
        HStack(spacing: 12) {
            InputMethodButton(icon: "camera.fill", label: "Camera",
                              color: DesignSystem.accentColor) {
                HapticManager.shared.lightImpact()
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    showCameraPicker = true
                } else {
                    showImagePicker = true
                }
            }
            InputMethodButton(icon: "photo.on.rectangle.angled", label: "Photo",
                              color: Color(red: 0.47, green: 0.27, blue: 0.90)) {
                HapticManager.shared.lightImpact()
                showImagePicker = true
            }
            InputMethodButton(icon: "doc.fill", label: "PDF",
                              color: Color(red: 0.9, green: 0.35, blue: 0.15)) {
                HapticManager.shared.lightImpact()
                showDocumentPicker = true
            }
        }
        .padding(.horizontal, 24)
    }

    private var contractTextEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
                    )
                TextEditor(text: $viewModel.contractText)
                    .font(.system(size: 14))
                    .padding(14)
                    .frame(minHeight: 200)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                if viewModel.contractText.isEmpty {
                    Text("Paste your contract text here\u{2026}")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(20)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 200)
            if !viewModel.contractText.isEmpty {
                Text("\(viewModel.contractText.count) characters")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 24)
    }

    private var scanButton: some View {
        let isEmpty = viewModel.contractText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return Button(action: {
            HapticManager.shared.mediumImpact()
            Task { await viewModel.analyzeText() }
        }) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.system(size: 20))
                Text("Scan for Red Flags")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isEmpty ? DesignSystem.accentColor.opacity(0.4) : DesignSystem.accentColor)
            .cornerRadius(32)
        }
        .disabled(isEmpty)
        .padding(.horizontal, 24)
    }

    // MARK: - Loading View

    private func loadingView(status: String) -> some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated icon
            ZStack {
                Circle()
                    .fill(DesignSystem.accentColor.opacity(0.1))
                    .frame(width: 100, height: 100)

                // Pulsing opacity animation — iOS 16 compatible
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(DesignSystem.accentColor)
                    .rotationEffect(.degrees(scanIconRotation))
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 1.2)
                            .repeatForever(autoreverses: true)
                        ) {
                            scanIconRotation = 8
                        }
                    }
                    .onDisappear { scanIconRotation = 0 }
            }

            VStack(spacing: 12) {
                Text("Analysing Contract")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)

                Text(status)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut, value: status)
                    .id(status) // forces text transition on change
                    .transition(.opacity)
            }

            ProgressView()
                .scaleEffect(1.2)
                .tint(DesignSystem.accentColor)

            Spacer()

            Text("Powered by Gemini 2.5")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.5))
                .padding(.bottom, 40)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            VStack(spacing: 8) {
                Text("Analysis Failed")
                    .font(.title3.bold())
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Button("Try Again") {
                HapticManager.shared.lightImpact()
                withAnimation { viewModel.reset() }
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignSystem.accentColor)

            Spacer()
        }
    }
}

// MARK: - Results Dashboard

struct ResultsDashboardView: View {
    let result: ContractAnalysisResult
    var onReset: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // Nav bar
                HStack {
                    Button(action: onReset) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(DesignSystem.accentColor)
                        Text("New Scan")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(DesignSystem.accentColor)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                // Safety gauge
                SafetyGaugeView(
                    score: result.safetyScore,
                    label: result.scoreLabel,
                    summary: result.summary
                )
                .padding(.top, 8)

                // Stats row
                if !result.dangerClauses.isEmpty || !result.safeClauses.isEmpty {
                    HStack(spacing: 16) {
                        StatPill(
                            count: result.dangerClauses.count,
                            label: "Red Flags",
                            color: Color(red: 0.9, green: 0.15, blue: 0.15)
                        )
                        StatPill(
                            count: result.safeClauses.count,
                            label: "Safe Clauses",
                            color: Color(red: 0.15, green: 0.75, blue: 0.47)
                        )
                    }
                    .padding(.horizontal, 24)
                }

                // Red flags section
                if !result.dangerClauses.isEmpty {
                    sectionHeader(title: "Red Flags", icon: "exclamationmark.triangle.fill", color: Color(red: 0.9, green: 0.15, blue: 0.15))

                    VStack(spacing: 12) {
                        ForEach(result.dangerClauses) { clause in
                            FlagCardView(clause: clause)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Safe clauses section
                if !result.safeClauses.isEmpty {
                    sectionHeader(title: "Positive Clauses", icon: "checkmark.shield.fill", color: Color(red: 0.15, green: 0.75, blue: 0.47))

                    VStack(spacing: 12) {
                        ForEach(result.safeClauses) { clause in
                            FlagCardView(clause: clause)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Footer disclaimer
                Text("This analysis is for informational purposes only and does not constitute legal advice. Consult a licensed attorney before signing any agreement.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
    }

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 4)
    }
}

// MARK: - Supporting sub-views

private struct InputMethodButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(color)
                }
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

private struct StatPill: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.08))
        .cornerRadius(14)
    }
}

// MARK: - Camera Picker (wraps UIImagePickerController for camera source)

struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.selectedImage = (info[.editedImage] ?? info[.originalImage]) as? UIImage
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Document Picker (PDF)

struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.pdf]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView
        init(_ parent: DocumentPickerView) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onPick(url)
        }
    }
}

#Preview {
    ContractScannerView()
}
