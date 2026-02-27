//
//  Service.swift
//  lawgpt
//
//  Created by Bash33r on 01/12/25.
//

import Foundation
import UIKit
import Combine

/// Service for interacting with  API via REST API (no SDK)
/// Based on official  API documentation: https://ai.google.dev/-api/docs
@MainActor
class GeminiService: ObservableObject {
    // MARK: - Configuration
    
    private let apiKey = Secrets.geminiAPIKey
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    private let primaryModelName = "gemini-2.5-flash"
    private let fallbackModelName = "gemini-2.5-flash-lite"
    private var currentModelName: String
    
    // DEBUG: Set to true to simulate quota exhaustion for testing
    static var simulateQuotaExhausted: Bool = false
    
    init() {
        self.currentModelName = primaryModelName
    }
    
    // Chat history for multi-turn conversations
    private var chatHistory: [ChatContent] = []
    
    @Published var isLoading = false
    @Published var currentResponse = ""
    @Published var error: String?
    
    // MARK: - System Instructions
    
    private func getSystemInstruction(for mode: ChatMode) -> String {
        switch mode {
        case .general:
            return """
            You are LawGPT, a helpful legal information assistant. Your role is to provide accurate, 
            well-researched legal information from authoritative sources.

            CRITICAL REQUIREMENTS (MUST FOLLOW):
            ====================================
            
            1. **MANDATORY INLINE CITATIONS**: You MUST include inline numbered citations like [1], [2], [3] etc. 
               within the response text after EACH legal claim or statute reference that needs a source. 
               Example: "The statute of limitations for breach of contract is typically 4-6 years[1][2]. 
               However, this varies by jurisdiction[1][3]."
               
            2. **NO SOURCES SECTION**: NEVER include a "Sources:" heading, "Sources:" paragraph, or numbered list of sources 
               in the response body text. The app will display sources separately.
               
            3. **CITATION FORMAT**: Use EXACT format [1], [2], [3] - square brackets with numbers, no spaces, 
               placed immediately after the relevant sentence or phrase.
            
            Guidelines:
            1. Prioritize information from authoritative legal sources (statutes, case law, legal databases like Westlaw, 
               LexisNexis, legal journals, court opinions, regulatory agencies, etc.)
            2. Be clear that you provide legal information, not legal advice
            3. If a question requires professional legal counsel, recommend consulting a licensed attorney
            4. Present information in a clear, organized manner with bullet points or numbered lists when appropriate
            5. Include relevant case citations, statute references, and legal precedents when available
            6. Explain legal terms in accessible language while maintaining accuracy
            7. Never use tables or pipe-separated columns; present content with sentences or bullet lists instead.
            8. Never return placeholder text like "URL unavailable"—provide real URLs or omit the source entirely.
            9. Provide at least 4-6 bullet points (or concise paragraphs) plus a brief summary paragraph.

            Response Format:
            - Use inline citations [1], [2], etc. after each legal claim
            - Place citations immediately after sentences, like this: "Legal statement here[1][2]."
            - Multiple citations can be grouped: [1][2][3]
            - Clear headings when appropriate
            - A summary of key legal points for complex topics
            - ABSOLUTELY NO "Sources:" section or numbered source list in the text
            
            Follow-Up Questions Section:
            - At the END of your response, include 3-5 educational follow-up questions
            - These questions must be purely educational and informational, NOT personal
            - Good examples: "What are the elements of [legal concept]?", "How does [statute] apply?", 
              "What are common defenses to [legal claim]?", "What is the standard of proof for [legal matter]?"
            - Bad examples: "Do you have a case?", "Are you being sued?", "What should you do?" (too specific/personal)
            - Separate the follow-up questions section with this EXACT delimiter on its own line:
              ---FOLLOW_UP_QUESTIONS---
            - List questions one per line, no numbering or bullets
            - Example format:
              [Your main response with citations here]
              
              ---FOLLOW_UP_QUESTIONS---
              What are the elements of a valid contract?
              How is breach of contract proven?
              What are the remedies available for breach of contract?
              What is the statute of limitations for contract claims?
            """
        case .contracts:
             return """
            You are LawGPT, specialized in contract law and contract analysis. 
            Focus on contract terms, clauses, legal requirements, contract interpretation, and contract formation.
            
            Guidelines:
            1. Prioritize official contract law sources, UCC provisions, contract interpretation case law, and statutory requirements.
            2. Always cite sources [1], [2].
            3. Be precise with contract terminology, legal requirements, and statutory provisions.
            4. State contract formation requirements, essential elements, and enforceability clearly.
            5. Always include numbered citations inline ([1], [2], etc.) tied to a Sources list; list each source with title and URL. If no sources are available, explicitly state that sources are unavailable and do not fabricate.
            6. Never use tables or pipe-separated columns; present content with sentences or bullet lists instead.
            7. Do NOT include an inline "Sources:" paragraph in the response body; rely on inline citations plus the structured sources list only.
            8. Never return placeholder text like "URL unavailable"—provide real URLs or omit the source entirely. If a URL is not known, exclude that source.
            9. Provide at least 4-6 bullet points (or concise paragraphs) plus a brief summary paragraph.
            10. Prefer including the direct source URL for each citation so the app can render clickable source cards.
            
            Follow-Up Questions Section:
            - At the END of your response, include 3-5 educational follow-up questions
            - These questions must be purely educational and informational, NOT personal
            - Good examples: "What are the essential elements of a contract?", "How are contracts interpreted?", 
              "What makes a contract unenforceable?", "What are common contract clauses?"
            - Bad examples: "Is your contract valid?", "Should you sign this?" (too specific/personal)
            - Separate the follow-up questions section with this EXACT delimiter on its own line:
              ---FOLLOW_UP_QUESTIONS---
            - List questions one per line, no numbering or bullets
            """
        case .caseLaw:
            return """
            You are LawGPT, specialized in case law research and legal precedents.
            Focus on relevant cases, court decisions, legal precedents, and judicial reasoning.
            
            Guidelines:
            1. Prioritize major case databases (Westlaw, LexisNexis, court opinions, appellate decisions, Supreme Court cases).
            2. Cite specific cases with proper legal citation format [1].
            3. Summarize case facts, holding, and reasoning clearly.
            4. Discuss how cases relate to the question asked and their precedential value.
            5. Always include numbered citations inline ([1], [2], etc.) tied to a Sources list; list each source with title and URL. If no sources are available, explicitly state that sources are unavailable and do not fabricate.
            6. Never use tables or pipe-separated columns; present content with sentences or bullet lists instead.
            7. Do NOT include an inline "Sources:" paragraph in the response body; rely on inline citations plus the structured sources list only.
            8. Never return placeholder text like "URL unavailable"—provide real URLs or omit the source entirely. If a URL is not known, exclude that source.
            9. Provide at least 4-6 bullet points (or concise paragraphs) plus a brief summary paragraph.
            10. Prefer including the direct source URL for each citation so the app can render clickable source cards.
            
            Follow-Up Questions Section:
            - At the END of your response, include 3-5 educational follow-up questions
            - These questions must be purely educational and informational, NOT personal
            - Good examples: "What are the key holdings in similar cases?", "How has this precedent been applied?", 
              "What are the distinguishing factors in related cases?", "What is the current status of this legal doctrine?"
            - Bad examples: "Does this case apply to you?", "Are you in a similar situation?" (too specific/personal)
            - Separate the follow-up questions section with this EXACT delimiter on its own line:
              ---FOLLOW_UP_QUESTIONS---
            - List questions one per line, no numbering or bullets
            """
        case .regulations:
            return """
            You are LawGPT, specialized in regulatory law and compliance.
            Focus on federal and state regulations, compliance requirements, regulatory frameworks, and administrative law.
            
            Guidelines:
            1. Prioritize official regulatory sources (CFR, state regulations, agency guidance, administrative rules, federal register).
            2. Cite the specific regulation section and year [1].
            3. Present regulatory requirements, compliance obligations, and enforcement mechanisms clearly.
            4. Discuss how regulations apply to different situations and jurisdictions.
            5. Always include numbered citations inline ([1], [2], etc.) tied to a Sources list; list each source with title and URL. If no sources are available, explicitly state that sources are unavailable and do not fabricate.
            6. Never use tables or pipe-separated columns; present content with sentences or bullet lists instead.
            7. Do NOT include an inline "Sources:" paragraph in the response body; rely on inline citations plus the structured sources list only.
            8. Never return placeholder text like "URL unavailable"—provide real URLs or omit the source entirely. If a URL is not known, exclude that source.
            9. Provide at least 4-6 bullet points (or concise paragraphs) plus a brief summary paragraph.
            10. Prefer including the direct source URL for each citation so the app can render clickable source cards.
            
            Follow-Up Questions Section:
            - At the END of your response, include 3-5 educational follow-up questions
            - These questions must be purely educational and informational, NOT personal
            - Good examples: "What are the key compliance requirements?", "How are these regulations enforced?", 
              "What are the penalties for non-compliance?", "What is the regulatory framework for [topic]?"
            - Bad examples: "Are you in compliance?", "Should you be worried?" (too specific/personal)
            - Separate the follow-up questions section with this EXACT delimiter on its own line:
              ---FOLLOW_UP_QUESTIONS---
            - List questions one per line, no numbering or bullets
            """
        }
    }
    
    // MARK: - Chat Methods
    
    /// Start a new chat session
    func startNewChat() {
        chatHistory = []
    }
    
    /// Continue existing chat with history
    func continueChat(with history: [Message]) {
        chatHistory = history.compactMap { message in
            ChatContent(
                role: message.role == "user" ? "user" : "model",
                parts: [ChatPart(text: message.content ?? "")]
            )
        }
    }
    
    /// Add image message to history (for multi-turn with images)
    func addImageToHistory(image: UIImage, text: String) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        let base64Image = imageData.base64EncodedString()
        chatHistory.append(ChatContent(
            role: "user",
            parts: [
                ChatPart(text: text),
                ChatPart(imageData: base64Image, mimeType: "image/jpeg")
            ]
        ))
    }
    
    /// Parse follow-up questions from response using delimiter
    private func parseFollowUpQuestions(from response: String) -> [String] {
        let delimiter = "---FOLLOW_UP_QUESTIONS---"
        
        // Split by delimiter
        let parts = response.components(separatedBy: delimiter)
        
        // If delimiter found, extract questions from the second part
        guard parts.count > 1 else { return [] }
        
        let questionsSection = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Split by newlines and clean up
        let questions = questionsSection.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { $0.count > 10 } // Filter out very short lines
        
        return Array(questions.prefix(5)) // Return up to 5 questions
    }
    
    /// Extract main response content (removing follow-up questions section)
    private func extractMainResponse(from fullResponse: String) -> String {
        let delimiter = "---FOLLOW_UP_QUESTIONS---"
        
        // If delimiter found, return only the part before it
        if let delimiterRange = fullResponse.range(of: delimiter) {
            return String(fullResponse[..<delimiterRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // No delimiter, return full response
        return fullResponse
    }
    
    /// Send a message with an image and get response
    func sendMessageWithImage(_ text: String, image: UIImage, mode: ChatMode = .general) async -> (response: String, sources: [Source], followUpQuestions: [String]) {
        isLoading = true
        currentResponse = ""
        error = nil
        
        // DEBUG: Simulate quota exhaustion if flag is set (only for primary model, not fallback)
        if Self.simulateQuotaExhausted && currentModelName == primaryModelName {
            isLoading = false
            return ("QUOTA_EXHAUSTED: The service is temporarily unavailable due to high demand. Please try again with the fallback model.", [], [])
        }
        
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            error = "Failed to process image"
            isLoading = false
            return ("Failed to process image", [], [])
        }
        let base64Image = imageData.base64EncodedString()
        
        // Add user message with image to history
        chatHistory.append(ChatContent(role: "user", parts: [
            ChatPart(text: text),
            ChatPart(imageData: base64Image, mimeType: "image/jpeg")
        ]))
        
        var fullResponse = ""
        var allSources: [Source] = []
        var lastResponseData: [String: Any] = [:]
        
        do {
            // Make streaming request with image
            let responseStream = try await makeStreamingRequestWithImage(text: text, imageBase64: base64Image, mode: mode)
            
            for try await chunk in responseStream {
                if let text = extractText(from: chunk) {
                    fullResponse += text
                    currentResponse = fullResponse
                }
                
                if let sources = extractSources(from: chunk) {
                    for source in sources {
                        if !allSources.contains(where: { $0.url == source.url }) {
                            allSources.append(source)
                        }
                    }
                }
                
                if let data = try? JSONSerialization.jsonObject(with: chunk) as? [String: Any] {
                    lastResponseData = data
                }
            }
            
            if !lastResponseData.isEmpty {
                let finalSources = extractSourcesFromResponse(lastResponseData)
                for source in finalSources {
                    if !allSources.contains(where: { $0.url == source.url && $0.title == source.title }) {
                        allSources.append(source)
                    }
                }
            }
            
            // Resolve redirect URLs
            var resolvedSources: [Source] = []
            for source in allSources {
                if source.url.contains("vertexaisearch") || source.url.contains("grounding-api-redirect") {
                    print("🔄 Resolving redirect for: \(source.title)")
                    let resolvedURL = await followRedirect(source.url)
                    let resolvedSource = Source(
                        title: source.title,
                        url: resolvedURL,
                        snippet: source.snippet,
                        favicon: source.favicon
                    )
                    resolvedSources.append(resolvedSource)
                } else {
                    resolvedSources.append(source)
                }
            }
            allSources = resolvedSources
            
            // Filter out unwanted sources (dr.oracle ai, internal tools, etc.)
            allSources = allSources.filter { source in
                !shouldExcludeSource(url: source.url, title: source.title)
            }
            
            // Extract main response and follow-up questions
            let mainResponse = extractMainResponse(from: fullResponse)
            let followUpQuestions = parseFollowUpQuestions(from: fullResponse)
            
            // Store only main response in chat history (without follow-up questions)
            if !mainResponse.isEmpty {
                chatHistory.append(ChatContent(role: "model", parts: [ChatPart(text: mainResponse)]))
            }
            
            isLoading = false
            return (mainResponse, allSources, followUpQuestions)
            
        } catch {
            let errorDescription: String
            if let apiError = error as? GeminiAPIError {
                errorDescription = apiError.localizedDescription
                print("❌  API Error in sendMessageWithImage (GeminiAPIError):")
                print("   \(apiError.localizedDescription)")
                if case .httpError(let statusCode, let message) = apiError {
                    print("   HTTP Status: \(statusCode)")
                    print("   Message: \(message)")
                }
            } else if let urlError = error as? URLError {
                errorDescription = "Network error: \(urlError.localizedDescription)"
                print("❌  API Error in sendMessageWithImage (URLError):")
                print("   Code: \(urlError.code.rawValue)")
                print("   Description: \(urlError.localizedDescription)")
            } else {
                errorDescription = error.localizedDescription
                print("❌  API Error in sendMessageWithImage (Unknown):")
                print("   Error: \(errorDescription)")
                print("   Error type: \(type(of: error))")
            }
            
            self.error = errorDescription
            isLoading = false
            
            // Check if quota exhausted - return special indicator for fallback
            if let apiError = error as? GeminiAPIError, case .httpError(429, _) = apiError {
                // Return special error message that indicates quota exhaustion (will be checked in ChatViewModel)
                return ("QUOTA_EXHAUSTED: The service is temporarily unavailable due to high demand. Please try again with the fallback model.", [], [])
            }
            
            return ("I apologize, but I encountered an error while analyzing the image. Please try again.", [], [])
        }
    }
    
    /// Send a message and get streaming response with source extraction
    func sendMessage(_ text: String, mode: ChatMode = .general) async -> (response: String, sources: [Source], followUpQuestions: [String]) {
        isLoading = true
        currentResponse = ""
        error = nil
        
        // DEBUG: Simulate quota exhaustion if flag is set (only for primary model, not fallback)
        if Self.simulateQuotaExhausted && currentModelName == primaryModelName {
            isLoading = false
            return ("QUOTA_EXHAUSTED: The service is temporarily unavailable due to high demand. Please try again with the fallback model.", [], [])
        }
        
        // Add user message to history
        chatHistory.append(ChatContent(role: "user", parts: [ChatPart(text: text)]))
        
        var fullResponse = ""
        var allSources: [Source] = []
        var lastResponseData: [String: Any] = [:]
        
        do {
            // Make streaming request
            let responseStream = try await makeStreamingRequest(mode: mode)
            
            for try await chunk in responseStream {
                // Parse chunk and extract text
                if let text = extractText(from: chunk) {
                    fullResponse += text
                    currentResponse = fullResponse
                }
                
                // Extract sources from chunk
                if let sources = extractSources(from: chunk) {
                    for source in sources {
                        if !allSources.contains(where: { $0.url == source.url }) {
                            allSources.append(source)
                        }
                    }
                }
                
                // Store chunks for source extraction
                if let data = try? JSONSerialization.jsonObject(with: chunk) as? [String: Any] {
                    lastResponseData = data
                    // Try extracting sources from this chunk immediately
                    if let sources = extractSources(from: chunk) {
                        for source in sources {
                            if !allSources.contains(where: { $0.url == source.url && $0.title == source.title }) {
                                allSources.append(source)
                            }
                        }
                    }
                }
            }
            
            // Always extract sources from final chunk (sources often only appear at end)
            if !lastResponseData.isEmpty {
                let finalSources = extractSourcesFromResponse(lastResponseData)
                // Merge final sources with any sources found during streaming
                for source in finalSources {
                    if !allSources.contains(where: { $0.url == source.url && $0.title == source.title }) {
                        allSources.append(source)
                    }
                }
            }
            
            // Resolve redirect URLs
            var resolvedSources: [Source] = []
            for source in allSources {
                if source.url.contains("vertexaisearch") || source.url.contains("grounding-api-redirect") {
                    print("🔄 Resolving redirect for: \(source.title)")
                    let resolvedURL = await followRedirect(source.url)
                    let resolvedSource = Source(
                        title: source.title,
                        url: resolvedURL,
                        snippet: source.snippet,
                        favicon: source.favicon
                    )
                    resolvedSources.append(resolvedSource)
                } else {
                    resolvedSources.append(source)
                }
            }
            allSources = resolvedSources
            
            // Filter out unwanted sources (dr.oracle ai, internal tools, etc.)
            allSources = allSources.filter { source in
                !shouldExcludeSource(url: source.url, title: source.title)
            }
            
            // Debug: Print source count
            if !allSources.isEmpty {
                print("✅ Extracted \(allSources.count) sources (redirects resolved and filtered)")
            } else {
                print("⚠️ No sources found in response")
            }
            
            // Extract main response and follow-up questions
            let mainResponse = extractMainResponse(from: fullResponse)
            let followUpQuestions = parseFollowUpQuestions(from: fullResponse)
            
            // Store only main response in chat history (without follow-up questions)
            if !mainResponse.isEmpty {
                chatHistory.append(ChatContent(role: "model", parts: [ChatPart(text: mainResponse)]))
            }
            
            isLoading = false
            return (mainResponse, allSources, followUpQuestions)
            
        } catch {
            let errorDescription: String
            if let apiError = error as? GeminiAPIError {
                errorDescription = apiError.localizedDescription
                print("❌  API Error in sendMessage (GeminiAPIError):")
                print("   \(apiError.localizedDescription)")
                if case .httpError(let statusCode, let message) = apiError {
                    print("   HTTP Status: \(statusCode)")
                    print("   Message: \(message)")
                }
            } else if let urlError = error as? URLError {
                errorDescription = "Network error: \(urlError.localizedDescription)"
                print("❌  API Error in sendMessage (URLError):")
                print("   Code: \(urlError.code.rawValue)")
                print("   Description: \(urlError.localizedDescription)")
            } else {
                errorDescription = error.localizedDescription
                print("❌  API Error in sendMessage (Unknown):")
                print("   Error: \(errorDescription)")
                print("   Error type: \(type(of: error))")
            }
            
            self.error = errorDescription
            isLoading = false
            
            // Check if quota exhausted - return special indicator for fallback
            if let apiError = error as? GeminiAPIError, case .httpError(429, _) = apiError {
                // Return special error message that indicates quota exhaustion (will be checked in ChatViewModel)
                return ("QUOTA_EXHAUSTED: The service is temporarily unavailable due to high demand. Please try again with the fallback model.", [], [])
            }
            
            return ("I apologize, but I encountered an error while processing your request. Please try again.", [], [])
        }
    }
    
    // MARK: - REST API Implementation
    
    /// Switch to fallback model (for quota exhaustion scenarios)
    func useFallbackModel() {
        currentModelName = fallbackModelName
        print("🔄 Switched to fallback model: \(fallbackModelName)")
    }
    
    /// Reset to primary model
    func usePrimaryModel() {
        currentModelName = primaryModelName
    }
    
    /// Make a streaming request to  API using SSE (Server-Sent Events)
    private func makeStreamingRequest(mode: ChatMode) async throws -> AsyncThrowingStream<Data, any Error> {
        let urlString = "\(baseURL)/models/\(currentModelName):streamGenerateContent?alt=sse"
        guard let url = URL(string: urlString) else {
            throw GeminiAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        
        // Build request payload
        let payload = buildRequestPayload(mode: mode)
        
        // DEBUG: Log payload to verify tools are included
        if let tools = payload["tools"] as? [[String: Any]] {
            print("🔍 DEBUG: Request payload tools: \(tools)")
        } else {
            print("⚠️ DEBUG: No tools found in payload!")
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: GeminiAPIError.invalidResponse)
                        return
                    }
                    
                    guard (200...299).contains(httpResponse.statusCode) else {
                        var errorMessage = "HTTP Error \(httpResponse.statusCode)"
                        // Try to read error message
                        do {
                            var errorData = Data()
                            for try await byte in bytes {
                                errorData.append(byte)
                            }
                            if let message = String(data: errorData, encoding: .utf8) {
                                errorMessage = message
                            }
                        } catch {
                            // Ignore errors when reading error response
                        }
                        continuation.finish(throwing: GeminiAPIError.httpError(httpResponse.statusCode, errorMessage))
                        return
                    }
                    
                    // Parse SSE stream incrementally
                    // SSE format: "data: {...}\n\n"
                    let parser = SSEParser()
                    var eventBuffer = Data()
                    
                    for try await byte in bytes {
                        eventBuffer.append(byte)
                        
                        // Check for complete SSE event (ends with \n\n)
                        if eventBuffer.count >= 2,
                           eventBuffer.suffix(2) == Data([0x0A, 0x0A]) { // \n\n
                            if let eventString = String(data: eventBuffer.dropLast(2), encoding: .utf8),
                               !eventString.isEmpty {
                                parser.parse(eventData: eventString) { chunk in
                                    continuation.yield(chunk)
                                }
                            }
                            eventBuffer.removeAll()
                        }
                    }
                    
                    // Process any remaining data
                    if !eventBuffer.isEmpty,
                       let eventString = String(data: eventBuffer, encoding: .utf8),
                       !eventString.isEmpty {
                        parser.parse(eventData: eventString) { chunk in
                            continuation.yield(chunk)
                        }
                    }
                    
                    continuation.finish()
                    
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                // Cleanup handled by Task cancellation
            }
        }
    }
    
    /// Make a streaming request with image
    private func makeStreamingRequestWithImage(text: String, imageBase64: String, mode: ChatMode) async throws -> AsyncThrowingStream<Data, any Error> {
        let urlString = "\(baseURL)/models/\(currentModelName):streamGenerateContent?alt=sse"
        guard let url = URL(string: urlString) else {
            throw GeminiAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        
        // Build request payload with image
        let payload = buildRequestPayloadWithImage(text: text, imageBase64: imageBase64, mode: mode)
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: GeminiAPIError.invalidResponse)
                        return
                    }
                    
                    guard (200...299).contains(httpResponse.statusCode) else {
                        var errorMessage = "HTTP Error \(httpResponse.statusCode)"
                        do {
                            var errorData = Data()
                            for try await byte in bytes {
                                errorData.append(byte)
                            }
                            if let message = String(data: errorData, encoding: .utf8) {
                                errorMessage = message
                            }
                        } catch {}
                        continuation.finish(throwing: GeminiAPIError.httpError(httpResponse.statusCode, errorMessage))
                        return
                    }
                    
                    let parser = SSEParser()
                    var eventBuffer = Data()
                    
                    for try await byte in bytes {
                        eventBuffer.append(byte)
                        
                        if eventBuffer.count >= 2,
                           eventBuffer.suffix(2) == Data([0x0A, 0x0A]) {
                            if let eventString = String(data: eventBuffer.dropLast(2), encoding: .utf8),
                               !eventString.isEmpty {
                                parser.parse(eventData: eventString) { chunk in
                                    continuation.yield(chunk)
                                }
                            }
                            eventBuffer.removeAll()
                        }
                    }
                    
                    if !eventBuffer.isEmpty,
                       let eventString = String(data: eventBuffer, encoding: .utf8),
                       !eventString.isEmpty {
                        parser.parse(eventData: eventString) { chunk in
                            continuation.yield(chunk)
                        }
                    }
                    
                    continuation.finish()
                    
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { @Sendable _ in }
        }
    }
    
    /// Build request payload with image
    private func buildRequestPayloadWithImage(text: String, imageBase64: String, mode: ChatMode) -> [String: Any] {
        var payload: [String: Any] = [:]
        
        payload["systemInstruction"] = [
            "parts": [
                ["text": getSystemInstruction(for: mode)]
            ]
        ]
        
        payload["contents"] = [
            [
                "role": "user",
                "parts": [
                    ["text": text],
                    [
                        "inlineData": [
                            "mimeType": "image/jpeg",
                            "data": imageBase64
                        ]
                    ]
                ]
            ]
        ]
        
        payload["generationConfig"] = [
            "temperature": 0.7,
            "topP": 0.95,
            "topK": 40,
            "maxOutputTokens": 8192
        ]
        
        payload["tools"] = [
            [
                "google_search": [:] as [String: Any]
            ]
        ]
        
        return payload
    }
    
    /// Build request payload for  API
    private func buildRequestPayload(mode: ChatMode) -> [String: Any] {
        var payload: [String: Any] = [:]
        
        // System instruction
        payload["systemInstruction"] = [
            "parts": [
                ["text": getSystemInstruction(for: mode)]
            ]
        ]
        
        // Contents (chat history + current message)
        payload["contents"] = chatHistory.map { content in
            [
                "role": content.role,
                "parts": content.parts.map { part -> [String: Any] in
                    if let text = part.text {
                        return ["text": text] as [String: Any]
                    } else if let imageData = part.imageData, let mimeType = part.mimeType {
                        return [
                            "inlineData": [
                                "mimeType": mimeType,
                                "data": imageData
                            ] as [String: Any]
                        ] as [String: Any]
                    } else {
                        return [:] as [String: Any]
                    }
                }
            ]
        }
        
        // Generation config
        payload["generationConfig"] = [
            "temperature": 0.7,
            "topP": 0.95,
            "topK": 40,
            "maxOutputTokens": 8192
        ]
        
        // Tools - Google Search grounding
        payload["tools"] = [
            [
                "google_search": [:] as [String: Any]
            ]
        ]
        
        return payload
    }
    
    // MARK: - Response Parsing
    
    /// Extract text from SSE chunk
    private func extractText(from chunk: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: chunk) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            return nil
        }
        return cleanMarkdown(text)
    }
    
    /// Clean markdown formatting from text
    private func cleanMarkdown(_ text: String) -> String {
        let cleaned = text
        // NOTE: We no longer remove bold markdown to preserve formatting for the view
        // cleaned = cleaned.replacingOccurrences(of: "**", with: "")
        return cleaned
    }
    
    /// Extract sources from SSE chunk
    private func extractSources(from chunk: Data) -> [Source]? {
        guard let json = try? JSONSerialization.jsonObject(with: chunk) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let groundingMetadata = firstCandidate["groundingMetadata"] as? [String: Any] else {
            return nil
        }
        
        // Note: extractSourcesFromGroundingMetadata is now async, but we call it synchronously here
        // For streaming chunks, we'll extract sources synchronously and resolve redirects later if needed
        return extractSourcesFromGroundingMetadataSync(groundingMetadata)
    }
    
    /// Extract sources from full response
    private func extractSourcesFromResponse(_ response: [String: Any]) -> [Source] {
        // Try to get candidates
        guard let candidates = response["candidates"] as? [[String: Any]] else {
            print("⚠️ No candidates found in response")
            return []
        }
        
        var allSources: [Source] = []
        
        // Check all candidates for grounding metadata
        for (index, candidate) in candidates.enumerated() {
            if let groundingMetadata = candidate["groundingMetadata"] as? [String: Any] {
                print("📋 Found grounding metadata in candidate \(index + 1)")
                let sources = extractSourcesFromGroundingMetadataSync(groundingMetadata)
                // Merge sources from all candidates
                for source in sources {
                    if !allSources.contains(where: { $0.url == source.url && $0.title == source.title }) {
                        allSources.append(source)
                    }
                }
            } else {
                print("⚠️ Candidate \(index + 1) has no grounding metadata")
            }
        }
        
        return allSources
    }
    
    /// Clean Vertex AI redirect URLs to extract original source URLs
    /// Based on  API documentation: redirect URLs contain the original URL in query parameters
    private func cleanVertexAIURL(_ uri: String, title: String? = nil) -> String {
        // If URI is just a domain (no protocol), add https://
        if !uri.hasPrefix("http://") && !uri.hasPrefix("https://") && uri.contains(".") && !uri.contains(" ") {
            let normalizedURI = "https://\(uri)"
            print("  ℹ️ URI appears to be just a domain, normalized to: \(normalizedURI)")
            return normalizedURI
        }
        
        // Check if this is a Vertex AI redirect URL
        guard uri.contains("vertexaisearch.cloud.google.com") || uri.contains("vertexai") || uri.contains("grounding-api-redirect") else {
            // Not a Vertex AI URL, but check if it's a valid URL
            if uri.hasPrefix("http://") || uri.hasPrefix("https://") {
                return uri
            }
            // If it's not a valid URL, try to construct one
            if uri.contains(".") && !uri.contains(" ") {
                return "https://\(uri)"
            }
            return uri
        }
        
        print("🔍 Cleaning Vertex AI redirect URL: \(uri)")
        
        // Method 1: Extract from query parameters (most common)
        // Vertex AI redirect URLs typically have the original URL in query parameters
        if let urlObj = URL(string: uri),
           let components = URLComponents(url: urlObj, resolvingAgainstBaseURL: false) {
            
            // Check all query items for URL patterns
            if let queryItems = components.queryItems {
                // Try common parameter names in order of likelihood
                let paramNames = ["originalUrl", "url", "link", "source", "target", "redirect", "destination", "href", "source_url", "original_url"]
                
                for paramName in paramNames {
                    if let paramValue = queryItems.first(where: { $0.name.lowercased() == paramName.lowercased() })?.value,
                       !paramValue.isEmpty {
                        // Try URL decoding
                        let decoded = paramValue.removingPercentEncoding ?? paramValue
                        
                        // Check if it looks like a URL
                        if decoded.hasPrefix("http://") || decoded.hasPrefix("https://") {
                            // Verify it's not another redirect URL
                            if !decoded.contains("vertexaisearch") && !decoded.contains("grounding-api-redirect") {
                                print("  ✅ Found original URL in '\(paramName)' parameter: \(decoded)")
                                return decoded
                            }
                        }
                    }
                }
                
                // Also check all query items for any that contain URLs
                for item in queryItems {
                    if let value = item.value, !value.isEmpty {
                        let decoded = value.removingPercentEncoding ?? value
                        // Look for URL patterns in the value
                        if decoded.hasPrefix("http://") || decoded.hasPrefix("https://") {
                            if !decoded.contains("vertexaisearch") && !decoded.contains("grounding-api-redirect") {
                                print("  ✅ Found URL in '\(item.name)' parameter: \(decoded)")
                                return decoded
                            }
                        }
                    }
                }
            }
            
            // Method 2: Check fragment (sometimes URLs are in fragments)
            if let fragment = components.fragment, !fragment.isEmpty {
                let decodedFragment = fragment.removingPercentEncoding ?? fragment
                if decodedFragment.hasPrefix("http://") || decodedFragment.hasPrefix("https://") {
                    if !decodedFragment.contains("vertexaisearch") && !decodedFragment.contains("grounding-api-redirect") {
                        print("  ✅ Found URL in fragment: \(decodedFragment)")
                        return decodedFragment
                    }
                }
            }
            
            // Method 3: Parse the path for URL patterns (sometimes URLs are encoded in the path)
            let path = components.path
            if path.contains("http") {
                // Try to extract URL from path using regex
                if let urlMatch = path.range(of: #"https?://[^\s\)\?&]+"#, options: .regularExpression) {
                    let extractedURL = String(path[urlMatch])
                    if !extractedURL.contains("vertexaisearch") && !extractedURL.contains("grounding-api-redirect") {
                        print("  ✅ Found URL in path: \(extractedURL)")
                        return extractedURL
                    }
                }
            }
        }
        
        // Method 4: Parse the entire URI string for URL patterns (fallback)
        if let urlMatch = uri.range(of: #"https?://[^\s\)\?&]+"#, options: .regularExpression) {
            let extractedURL = String(uri[urlMatch])
            // Make sure it's not the redirect URL itself
            if !extractedURL.contains("vertexaisearch") && !extractedURL.contains("grounding-api-redirect") {
                print("  ✅ Found URL pattern in URI string: \(extractedURL)")
                return extractedURL
            }
        }
        
        // Method 5: Construct URL from title/domain if we have it (last resort)
        // This is a fallback when we can't extract the original URL
        if let title = title, uri.contains("grounding-api-redirect") {
            // Try to extract domain from title and construct a reasonable URL
            let domain = extractDomainFromTitle(title)
            if !domain.isEmpty, domain.contains(".") {
                // Construct a basic URL - assume HTTPS for most legal sources
                let constructedURL = "https://\(domain)"
                print("  ⚠️ Could not extract original URL from redirect, constructed from domain: \(constructedURL)")
                print("  ⚠️ Note: This may not be the exact page URL - redirect URL will be used as fallback")
                // Return the redirect URL instead of constructed domain, as redirect is more reliable
            }
        }
        
        // If we can't extract the original URL, return the redirect URL
        // The redirect URL will work when clicked (valid for 30 days per  API docs)
        print("  ⚠️ Could not extract original URL from redirect - using redirect URL (valid for 30 days)")
        return uri
    }
    
    /// Extract domain from title (e.g., "bhf.org.uk" from title)
    private func extractDomainFromTitle(_ title: String) -> String {
        // Remove common prefixes/suffixes that might be in titles
        var domain = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove common title prefixes
        let prefixesToRemove = ["Source: ", "From: ", "Cited from: "]
        for prefix in prefixesToRemove {
            if domain.hasPrefix(prefix) {
                domain = String(domain.dropFirst(prefix.count))
            }
        }
        
        // Check if it looks like a domain (contains at least one dot)
        if domain.contains(".") && !domain.contains(" ") {
            // It might already be a domain
            return domain
        }
        
        // Try to extract domain from URL-like patterns in the title
        if let urlMatch = domain.range(of: #"https?://([^\s/]+)"#, options: .regularExpression) {
            let urlString = String(domain[urlMatch])
            if let url = URL(string: urlString),
               let host = url.host {
                return host
            }
        }
        
        return ""
    }
    
    /// Follow redirect URL to get final destination (async)
    /// Based on  API docs: redirect URLs need to be followed to get actual source URLs
    /// URLSession automatically follows redirects, so we just need to check the final URL
    private func followRedirect(_ redirectURL: String) async -> String {
        guard let url = URL(string: redirectURL) else {
            print("  ⚠️ Invalid redirect URL: \(redirectURL)")
            return redirectURL
        }
        
        // Create a URLSession configuration that allows redirects
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = true
        config.httpCookieAcceptPolicy = .always
        
        let session = URLSession(configuration: config)
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD" // Use HEAD to avoid downloading content
        request.timeoutInterval = 10.0
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        
        do {
            // URLSession automatically follows redirects
            let (_, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                // The response.url should be the final URL after all redirects
                if let finalURL = httpResponse.url?.absoluteString {
                    // Verify it's not still a redirect URL
                    if !finalURL.contains("vertexaisearch") && !finalURL.contains("grounding-api-redirect") {
                        print("  ✅ Resolved redirect:")
                        print("     From: \(redirectURL)")
                        print("     To:   \(finalURL)")
                        return finalURL
                    } else {
                        print("  ⚠️ Redirect still points to Vertex AI URL: \(finalURL)")
                    }
                }
                
                // Check Location header as fallback (for intermediate redirects)
                if let locationHeader = httpResponse.value(forHTTPHeaderField: "Location"),
                   !locationHeader.isEmpty,
                   !locationHeader.contains("vertexaisearch") && !locationHeader.contains("grounding-api-redirect") {
                    // Make sure it's a full URL
                    if locationHeader.hasPrefix("http://") || locationHeader.hasPrefix("https://") {
                        print("  ✅ Found Location header: \(locationHeader)")
                        return locationHeader
                    }
                }
            }
        } catch {
            print("  ⚠️ Failed to follow redirect: \(error.localizedDescription)")
            // Try with GET method as fallback (some servers don't support HEAD)
            do {
                var getRequest = URLRequest(url: url)
                getRequest.httpMethod = "GET"
                getRequest.timeoutInterval = 10.0
                getRequest.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
                
                let (_, getResponse) = try await session.data(for: getRequest)
                if let httpResponse = getResponse as? HTTPURLResponse,
                   let finalURL = httpResponse.url?.absoluteString,
                   !finalURL.contains("vertexaisearch") && !finalURL.contains("grounding-api-redirect") {
                    print("  ✅ Resolved redirect with GET:")
                    print("     From: \(redirectURL)")
                    print("     To:   \(finalURL)")
                    return finalURL
                }
            } catch {
                print("  ⚠️ GET method also failed: \(error.localizedDescription)")
            }
        }
        
        // Fallback: return the redirect URL (valid for 30 days per  API docs)
        print("  ⚠️ Could not resolve redirect, using redirect URL (valid for 30 days)")
        return redirectURL
    }
    
    /// Extract sources from grounding metadata (synchronous version for streaming)
    /// This version doesn't follow redirects to avoid blocking
    private func extractSourcesFromGroundingMetadataSync(_ metadata: [String: Any]) -> [Source] {
        return extractSourcesFromGroundingMetadata(metadata, followRedirects: false)
    }
    
    /// Check if a source should be excluded (unwanted domains, internal tools, etc.)
    private func shouldExcludeSource(url: String, title: String?) -> Bool {
        let urlLower = url.lowercased()
        let titleLower = title?.lowercased() ?? ""
        
        // List of unwanted domains/patterns to filter out
        // NOTE: We do NOT filter out vertexaisearch or grounding-api-redirect URLs
        // because these are valid redirect URLs from  API that work for 30 days
        let unwantedPatterns = [
            "dr.oracle",
            "oracle.ai",
            "oracle.com",
            "google.com/search",
            "google.com/url",
            "internal",
            "tool",
            "generated"
        ]
        
        // Check if URL or title contains any unwanted pattern
        for pattern in unwantedPatterns {
            if urlLower.contains(pattern) || titleLower.contains(pattern) {
                return true
            }
        }
        
        return false
    }
    
    /// Extract sources from grounding metadata (internal implementation)
    private func extractSourcesFromGroundingMetadata(_ metadata: [String: Any], followRedirects: Bool = false) -> [Source] {
        var sources: [Source] = []
        
        // DEBUG: Log complete grounding metadata structure
        print("🔍 DEBUG: Complete grounding metadata structure:")
        if let metadataJSON = try? JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted),
           let metadataString = String(data: metadataJSON, encoding: .utf8) {
            print(metadataString)
        } else {
            print("  Raw metadata keys: \(Array(metadata.keys))")
        }
        
        // Try to get groundingChunks
        guard let groundingChunks = metadata["groundingChunks"] as? [[String: Any]] else {
            print("⚠️ No groundingChunks found in metadata")
            return []
        }
        
        print("📚 Found \(groundingChunks.count) grounding chunks")
        
        for (index, chunk) in groundingChunks.enumerated() {
            print("\n🔍 DEBUG: Processing chunk \(index + 1)")
            print("  Chunk keys: \(Array(chunk.keys))")
            
            // Check for web source
            if let web = chunk["web"] as? [String: Any] {
                // DEBUG: Log complete web object structure
                print("  🔍 DEBUG: Complete web object for chunk \(index + 1):")
                if let webJSON = try? JSONSerialization.data(withJSONObject: web, options: .prettyPrinted),
                   let webString = String(data: webJSON, encoding: .utf8) {
                    print(webString)
                } else {
                    print("    Web object keys: \(Array(web.keys))")
                    for (key, value) in web {
                        print("    \(key): \(value)")
                    }
                }
                
                // Extract all available fields from web object
                let uri = web["uri"] as? String
                let title = web["title"] as? String
                
                print("  📋 Raw values from web object:")
                print("    uri: \(uri ?? "nil")")
                print("    title: \(title ?? "nil")")
                
                // Check for alternative URL fields that might contain the original URL
                let originalUrl = web["originalUrl"] as? String
                let sourceUrl = web["sourceUrl"] as? String
                let link = web["link"] as? String
                let url = web["url"] as? String
                
                print("    originalUrl: \(originalUrl ?? "nil")")
                print("    sourceUrl: \(sourceUrl ?? "nil")")
                print("    link: \(link ?? "nil")")
                print("    url: \(url ?? "nil")")
                
                // Check all possible URL fields
                let originalURL = originalUrl ?? sourceUrl ?? link ?? url
                
                // Determine which URL to use - prefer original URL if available
                var finalURL = originalURL ?? uri ?? ""
                
                print("  🔗 URL extraction:")
                print("    Selected URL before cleaning: \(finalURL)")
                
                // If we only have a domain (like "who.int"), check if title contains more info
                if finalURL.isEmpty || (!finalURL.hasPrefix("http") && finalURL.contains(".") && !finalURL.contains("/")) {
                    // Check if title might contain the full URL
                    if let title = title, title.contains("http") {
                        if let urlMatch = title.range(of: #"https?://[^\s\)]+"#, options: .regularExpression) {
                            let extractedFromTitle = String(title[urlMatch])
                            print("    ℹ️ Extracted URL from title: \(extractedFromTitle)")
                            finalURL = extractedFromTitle
                        }
                    }
                }
                
                // Clean Vertex AI Search URIs if we still have a redirect
                if !finalURL.isEmpty {
                    let beforeClean = finalURL
                    finalURL = cleanVertexAIURL(finalURL, title: title)
                    if beforeClean != finalURL {
                        print("    URL after cleaning: \(finalURL)")
                    } else {
                        print("    URL unchanged after cleaning")
                    }
                }
                
                // If final URL is still just a domain, try to get more info from snippet
                if !finalURL.isEmpty && !finalURL.hasPrefix("http") {
                    if let snippet = web["snippet"] as? String, snippet.contains("http") {
                        if let urlMatch = snippet.range(of: #"https?://[^\s\)]+"#, options: .regularExpression) {
                            let extractedFromSnippet = String(snippet[urlMatch])
                            print("    ℹ️ Extracted URL from snippet: \(extractedFromSnippet)")
                            if !extractedFromSnippet.contains("vertexaisearch") {
                                finalURL = extractedFromSnippet
                            }
                        }
                    }
                }
                
                // If we still have a redirect URL and followRedirects is enabled, try to resolve it
                if followRedirects && (finalURL.contains("vertexaisearch") || finalURL.contains("grounding-api-redirect")) {
                    print("  🔄 Attempting to follow redirect...")
                    // Note: This would need to be called from an async context
                    // For now, we'll use the redirect URL - it will work for 30 days
                } else if finalURL.contains("vertexaisearch") || finalURL.contains("grounding-api-redirect") {
                    print("  ⚠️ Still have redirect URL - will be resolved when user clicks (valid for 30 days)")
                }
                
                // Ensure we have a valid URL format
                if !finalURL.isEmpty && !finalURL.hasPrefix("http://") && !finalURL.hasPrefix("https://") {
                    if finalURL.contains(".") && !finalURL.contains(" ") {
                        finalURL = "https://\(finalURL)"
                        print("    ℹ️ Normalized domain to full URL: \(finalURL)")
                    }
                }
                
                guard let title = title, !title.isEmpty else {
                    print("  ⚠️ Chunk \(index + 1) missing title (url: \(finalURL.isEmpty ? "empty" : "present"))")
                    continue
                }
                
                // If URL is empty but we have a title, try to construct a basic URL from title
                var urlToUse = finalURL
                if urlToUse.isEmpty {
                    // Try to extract domain from title
                    let domain = extractDomainFromTitle(title)
                    if !domain.isEmpty {
                        urlToUse = "https://\(domain)"
                        print("    ℹ️ Constructed URL from title: \(urlToUse)")
                    } else {
                        print("  ⚠️ Chunk \(index + 1) has no URL and cannot construct one from title")
                        continue
                    }
                }
                
                // Filter out unwanted sources (like dr.oracle ai, internal tools, etc.)
                // NOTE: Vertex AI redirect URLs are NOT filtered - they are valid and work for 30 days
                if shouldExcludeSource(url: urlToUse, title: title) {
                    print("  ⚠️ Chunk \(index + 1) filtered out (unwanted source):")
                    print("     Title: \(title)")
                    print("     URL: \(urlToUse)")
                    continue
                }
                
                let source = Source(
                    title: title,
                    url: urlToUse,
                    snippet: web["snippet"] as? String,
                    favicon: nil
                )
                
                if !sources.contains(where: { $0.url == source.url && $0.title == source.title }) {
                    sources.append(source)
                    print("  ✅ Source \(index + 1) extracted:")
                    print("     Title: \(title)")
                    print("     Final URL: \(urlToUse)")
                    print("     Snippet: \(web["snippet"] as? String ?? "nil")")
                }
            } else {
                print("  ⚠️ Chunk \(index + 1) missing web data")
                // Debug: print what fields are available
                print("     Available keys: \(Array(chunk.keys))")
                // Log the complete chunk structure
                if let chunkJSON = try? JSONSerialization.data(withJSONObject: chunk, options: .prettyPrinted),
                   let chunkString = String(data: chunkJSON, encoding: .utf8) {
                    print("     Complete chunk structure:")
                    print(chunkString)
                }
            }
        }
        
        // Debug: Print search queries
        if let webSearchQueries = metadata["webSearchQueries"] as? [String], !webSearchQueries.isEmpty {
            print("🔍 Search queries used: \(webSearchQueries)")
        }
        
        // Debug: Check for other top-level fields
        print("\n🔍 DEBUG: Top-level metadata fields:")
        for (key, value) in metadata {
            if key != "groundingChunks" && key != "webSearchQueries" {
                print("  \(key): \(value)")
            }
        }
        
        return sources
    }
    
    // MARK: - Contract Analysis

    /// Lightweight OCR: send an image to  Vision with NO legal system prompt.
    /// Returns the raw extracted text, or nil on failure.
    func ocrImage(_ image: UIImage) async -> String? {
        let urlString = "\(baseURL)/models/\(currentModelName):generateContent"
        guard let url = URL(string: urlString),
              let imageData = image.jpegData(compressionQuality: 0.85) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let payload: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": "Extract all text from this document image exactly as written. Return only the raw text — no commentary, no formatting changes, no labels."],
                        ["inlineData": ["mimeType": "image/jpeg", "data": imageData.base64EncodedString()]]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.0,
                "maxOutputTokens": 8192
            ]
        ]

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        request.httpBody = body

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json       = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let content    = candidates.first?["content"] as? [String: Any],
                  let parts      = content["parts"] as? [[String: Any]],
                  let text       = parts.first?["text"] as? String else { return nil }
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("❌ ocrImage error: \(error)")
            return nil
        }
    }

    /// Analyze a contract and return a structured JSON result for the ClauseGuard scanner.
    /// Uses the non-streaming generateContent endpoint so the full JSON can be cleanly decoded.
    /// Stable model pinned explicitly — -2.0-flash has reliable JSON-mode support.
    private let contractAnalysisModel = "gemini-2.5-flash"
    /// Characters to truncate contract text at before sending (~25 k chars ≈ ~6 000 tokens)
    private let contractTextCharLimit = 25_000

    func analyzeContract(_ contractText: String) async -> ContractAnalysisResult? {
        // Truncate oversized input so we never exceed the model's context / cost budget
        let inputText: String
        if contractText.count > contractTextCharLimit {
            print("⚠️ analyzeContract: text truncated from \(contractText.count) to \(contractTextCharLimit) chars")
            inputText = String(contractText.prefix(contractTextCharLimit))
        } else {
            inputText = contractText
        }

        let urlString = "\(baseURL)/models/\(contractAnalysisModel):generateContent"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let systemPrompt = """
        Role: You are an elite contract lawyer protecting a freelancer or founder.
        Task: Analyze the provided contract text. Identify the top 3 most dangerous clauses (type: "danger") and 2 favorable clauses (type: "safe"). If fewer dangerous or safe clauses exist, include as many as are present.

        You MUST return a valid JSON object ONLY — no markdown, no explanation, no code fences.

        JSON Structure:
        {
          "safety_score": (integer 0-100, where 100 is perfectly safe for the signing party),
          "summary": "(1 punchy sentence summarising the overall contract risk level)",
          "analysis": [
            {
              "type": "danger",
              "title": "(Short clause title, e.g. 'Aggressive Non-Compete')",
              "quote": "(Exact short excerpt from the contract — max 2 sentences)",
              "explanation": "(Why this clause is harmful for the signer — plain English, max 3 sentences)",
              "fix": "(Exact suggested replacement text or protective action)"
            }
          ]
        }

        Constraints:
        1. Prioritise: IP Assignment (pre-existing IP), Non-Competes (scope/duration), Payment Terms (net 30 or less).
        2. If those are absent, check: Termination at-will, Uncapped Liability, Broad Indemnification, Unfavourable Governing Law.
        3. danger clauses come first in the analysis array, then safe clauses.
        4. Tone: Professional, direct, protective.
        5. Output ONLY the JSON object — absolutely nothing before or after.
        """

        let payload: [String: Any] = [
            "systemInstruction": [
                "parts": [["text": systemPrompt]]
            ],
            "contents": [
                [
                    "role": "user",
                    "parts": [["text": "Analyze this contract:\n\n\(inputText)"]]
                ]
            ],
            "generationConfig": [
                "temperature": 0.2,
                "topP": 0.9,
                "maxOutputTokens": 4096,
                "responseMimeType": "application/json"
            ]
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        request.httpBody = httpBody

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                if let body = String(data: data, encoding: .utf8) {
                    print("❌ analyzeContract HTTP error: \(body)")
                }
                return nil
            }

            // Parse the outer  envelope to extract the inner JSON string
            guard let json       = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  !candidates.isEmpty else {
                // Surface block reason if present
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let feedback = json["promptFeedback"] as? [String: Any],
                   let reason = feedback["blockReason"] as? String {
                    print("❌ analyzeContract blocked: \(reason)")
                } else {
                    let raw = String(data: data, encoding: .utf8) ?? "(no body)"
                    print("❌ analyzeContract: empty/missing candidates. Body: \(raw.prefix(500))")
                }
                return nil
            }

            guard let first   = candidates.first,
                  let content = first["content"] as? [String: Any],
                  let parts   = content["parts"] as? [[String: Any]],
                  let rawText = parts.first?["text"] as? String else {
                let finishReason = (candidates.first?["finishReason"] as? String) ?? "unknown"
                print("❌ analyzeContract: Failed to parse  envelope. finishReason=\(finishReason)")
                return nil
            }

            // Strip potential markdown fences the model might still emit
            let cleaned = rawText
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard let jsonData = cleaned.data(using: .utf8) else { return nil }
            let result = try JSONDecoder().decode(ContractAnalysisResult.self, from: jsonData)
            print("✅ analyzeContract: score=\(result.safetyScore), clauses=\(result.analysis.count)")
            return result

        } catch {
            print("❌ analyzeContract error: \(error)")
            return nil
        }
    }

    // MARK: - Utility Methods

    var isConfigured: Bool {
        return !apiKey.isEmpty && apiKey != "YOUR__API_KEY"
    }
    
    func resetChat() {
        chatHistory = []
        currentResponse = ""
        error = nil
    }
}

// MARK: - Supporting Types

struct ChatContent {
    let role: String
    let parts: [ChatPart]
}

struct ChatPart {
    let text: String?
    let imageData: String?
    let mimeType: String?
    
    init(text: String) {
        self.text = text
        self.imageData = nil
        self.mimeType = nil
    }
    
    init(imageData: String, mimeType: String) {
        self.text = nil
        self.imageData = imageData
        self.mimeType = mimeType
    }
}

// MARK: - Error Types

enum GeminiAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case noData
    case httpError(Int, String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from API"
        case .noData:
            return "No data received from API"
        case .httpError(let code, let message):
            return "HTTP Error \(code): \(message)"
        }
    }
}

// MARK: - SSE Parser

/// Server-Sent Events parser for streaming responses
/// SSE format: "data: {...}\n\n"
class SSEParser {
    func parse(eventData: String, chunkHandler: @escaping (Data) -> Void) {
        // Split by lines
        let lines = eventData.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // SSE format: "data: {...}"
            if trimmedLine.hasPrefix("data: ") {
                let jsonString = String(trimmedLine.dropFirst(6))
                
                // Skip empty data lines and done signals
                if jsonString.isEmpty || jsonString == "[DONE]" {
                    continue
                }
                
                // Convert JSON string to Data
                if let jsonData = jsonString.data(using: .utf8) {
                    chunkHandler(jsonData)
                }
            }
        }
    }
}

// MARK: - Mock Service for Previews

class MockService: GeminiService {
    override init() {
        super.init()
    }
    
    override func sendMessage(_ text: String, mode: ChatMode = .general) async -> (response: String, sources: [Source], followUpQuestions: [String]) {
        isLoading = true
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        let mockResponse = """
        Based on current legal sources, here's what you should know:

        **Key Points:**
        1. This is a sample response demonstrating the format [1]
        2. Legal information should always be verified with a licensed attorney [2]
        3. Sources are provided for reference and further reading [3]

        **Recommendations:**
        - Consult with a licensed attorney for specific legal matters
        - Follow applicable statutes and regulations
        - Stay informed about relevant case law

        Please note that this information is for educational purposes only and should not replace professional legal advice [1][2].
        """
        
        let mockSources = [
            Source(title: "Legal Information Institute", url: "https://www.law.cornell.edu/", snippet: "Free legal information and resources."),
            Source(title: "Justia - Legal Resources", url: "https://www.justia.com/", snippet: "Comprehensive legal information and case law."),
            Source(title: "FindLaw", url: "https://www.findlaw.com/", snippet: "Legal information and attorney directory.")
        ]
        
        currentResponse = mockResponse
        isLoading = false
        
        return (mockResponse, mockSources, [])
    }
}
