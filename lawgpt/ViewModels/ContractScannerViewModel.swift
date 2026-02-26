//
//  ContractScannerViewModel.swift
//  lawgpt
//
//  Business logic for the ClauseGuard Red Flag Scanner.
//

import Foundation
import SwiftUI
import Combine
import PDFKit
import UniformTypeIdentifiers

@MainActor
class ContractScannerViewModel: ObservableObject {

    // MARK: - Scan state machine

    enum ScanState {
        case idle
        case loading(String)
        case result(ContractAnalysisResult)
        case error(String)

        var isLoading: Bool {
            if case .loading = self { return true }
            return false
        }
    }

    // MARK: - Published state

    @Published var contractText: String = ""
    @Published var scanState: ScanState = .idle
    @Published var selectedImage: UIImage? = nil
    @Published var pendingPDFName: String? = nil

    // MARK: - Private

    private let geminiService = GeminiService()

    private let loadingSteps: [String] = [
        "Scanning jurisdiction clauses...",
        "Analysing IP assignment...",
        "Checking payment terms...",
        "Reviewing non-compete scope...",
        "Detecting red flags...",
        "Generating suggested fixes..."
    ]
    private var loadingIndex = 0
    private var loadingTimer: Timer?

    // MARK: - Public API

    /// Analyse the contract text pasted by the user
    func analyzeText() async {
        let trimmed = contractText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await runAnalysis(text: trimmed)
    }

    /// Analyse a contract captured via camera / photo library
    func analyzeImage(_ image: UIImage) async {
        startLoading()
        // Use a plain vision call with no legal system prompt so we get raw text
        guard let extracted = await geminiService.ocrImage(image), !extracted.isEmpty else {
            stopLoading()
            scanState = .error("Could not extract text from image.\nPlease try pasting the contract text instead.")
            return
        }
        await runAnalysis(text: extracted)
    }

    /// Analyse a contract loaded from a PDF document picker URL
    func analyzePDF(url: URL) async {
        startLoading()
        // With asCopy:true the picker already placed the file in our sandbox —
        // no security-scoped resource access is needed.
        guard let pdf = PDFDocument(url: url) else {
            stopLoading()
            scanState = .error("The selected file could not be opened as a PDF.")
            return
        }

        var pages: [String] = []
        for i in 0..<pdf.pageCount {
            if let page = pdf.page(at: i), let pageText = page.string, !pageText.isEmpty {
                pages.append(pageText)
            }
        }

        let text = pages.joined(separator: "\n")
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            stopLoading()
            scanState = .error("No readable text found in the PDF.\n\nThis PDF may be image-based (scanned). Try the Camera option to photograph the contract pages instead.")
            return
        }

        print("📄 analyzePDF: \(pdf.pageCount) pages, \(trimmed.count) chars extracted from \(url.lastPathComponent)")
        pendingPDFName = url.lastPathComponent
        await runAnalysis(text: trimmed)
    }

    /// Reset everything back to idle
    func reset() {
        stopLoading()
        scanState = .idle
        contractText = ""
        selectedImage = nil
        pendingPDFName = nil
    }

    // MARK: - Private helpers

    private func runAnalysis(text: String) async {
        startLoading()
        print("🔍 runAnalysis: sending \(text.count) chars to Gemini")
        guard let result = await geminiService.analyzeContract(text) else {
            stopLoading()
            scanState = .error("Analysis failed. The AI could not parse the contract.\n\nTry pasting the key clauses as plain text instead.")
            return
        }
        stopLoading()
        scanState = .result(result)
    }

    private func startLoading() {
        loadingIndex = 0
        scanState = .loading(loadingSteps[0])
        loadingTimer?.invalidate()
        loadingTimer = Timer.scheduledTimer(withTimeInterval: 1.8, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.loadingIndex = (self.loadingIndex + 1) % self.loadingSteps.count
                if case .loading = self.scanState {
                    self.scanState = .loading(self.loadingSteps[self.loadingIndex])
                }
            }
        }
    }

    private func stopLoading() {
        loadingTimer?.invalidate()
        loadingTimer = nil
    }
}
