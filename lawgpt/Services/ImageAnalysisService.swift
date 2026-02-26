//
//  ImageAnalysisService.swift
//  lawgpt
//
//  Created by Bash33r on 01/12/25.
//

import Foundation
import UIKit
import Vision

/// Service for analyzing legal documents and images using Gemini Vision API
@MainActor
class ImageAnalysisService {
    private let geminiService: GeminiService
    
    init(geminiService: GeminiService? = nil) {
        self.geminiService = geminiService ?? GeminiService()
    }
    
    /// Analyze an image and generate legal insights
    func analyzeImage(_ image: UIImage, prompt: String? = nil) async -> (analysis: String, confidence: Double, sources: [Source]) {
        let defaultPrompt = """
        Analyze this legal document or image. Provide:
        1. A description of what you see
        2. Any relevant legal observations
        3. Important disclaimers about document analysis
        
        Note: This analysis is for informational purposes only and should not replace professional legal advice.
        """
        
        let analysisPrompt = prompt ?? defaultPrompt
        
        // Use Gemini Vision API to analyze the image
        let (response, sources, _) = await geminiService.sendMessageWithImage(
            analysisPrompt,
            image: image
        )
        
        // Calculate confidence (simplified - in production would use model confidence scores)
        let confidence = calculateConfidence(from: response)
        
        return (response, confidence, sources)
    }
    
    /// Extract text from legal documents using OCR
    func extractText(from image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { request, error in
            // Handle completion
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        do {
            try requestHandler.perform([request])
            
            guard let observations = request.results else {
                return nil
            }
            
            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            return recognizedStrings.joined(separator: "\n")
        } catch {
            print("OCR Error: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Analyze image and extract text, then provide legal insights
    func analyzeLegalDocument(_ image: UIImage) async -> (text: String?, analysis: String, sources: [Source]) {
        // First extract text
        let extractedText = await extractText(from: image)
        
        // Then analyze with context
        let prompt = """
        Analyze this legal document image. 
        \(extractedText != nil ? "Extracted text: \(extractedText!)" : "Please analyze the image visually.")
        
        Provide:
        1. Summary of the legal information
        2. Key findings or provisions
        3. Important notes or warnings
        
        Note: This analysis is for informational purposes only and should not replace professional legal advice.
        """
        
        let (analysis, _, sources) = await analyzeImage(image, prompt: prompt)
        
        return (extractedText, analysis, sources)
    }
    
    private func calculateConfidence(from response: String) -> Double {
        // Simplified confidence calculation
        // In production, would use model confidence scores
        
        // Higher confidence if response is detailed and contains legal terminology
        let legalTerms = ["contract", "statute", "regulation", "case", "legal", "law", "jurisdiction", "clause", "provision"]
        let hasLegalTerms = legalTerms.contains(where: { term in
            response.lowercased().contains(term)
        })
        
        let lengthScore = min(1.0, Double(response.count) / 500.0) // Normalize by length
        let legalScore = hasLegalTerms ? 0.3 : 0.0
        
        return min(1.0, lengthScore + legalScore + 0.4) // Base confidence of 0.4
    }
}
