//
//  ChatViewModel.swift
//  lawgpt
//
//  Created by Bash33r on 01/12/25.
//

import Foundation
import SwiftUI
import CoreData
import Combine

/// Sendable data extracted from Message for passing across actor boundaries
struct MessageData: Sendable {
    let role: String
    let content: String
}

//
//  ChatMode.swift
//  lawgpt
//
//  Created by Bash33r on 03/12/25.
//

import Foundation

enum ChatMode: String, CaseIterable, Identifiable {
    case general = "General Legal"
    case contracts = "Contracts"
    case caseLaw = "Case Law"
    case regulations = "Regulations"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .general: return "scale"
        case .contracts: return "doc.text"
        case .caseLaw: return "book.closed"
        case .regulations: return "list.bullet.rectangle"
        }
    }
}

/// ViewModel for managing chat state and interactions
@MainActor
class ChatViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var messages: [Message] = []
    @Published var inputText: String = "" {
        didSet {
            // Only save if text is not empty (don't save when clearing)
            if !inputText.isEmpty {
                saveDraftInput()
            }
        }
    }
    @Published var isLoading: Bool = false
    @Published var streamingResponse: String = ""
    @Published var animatedResponseText: String = ""
    @Published var isAnimatingResponse: Bool = false
    @Published var selectedSource: Source?
    @Published var showSourcePreview: Bool = false
    @Published var errorMessage: String?
    @Published var followUpSuggestions: [String] = []
    @Published var relatedTopics: [TopicCategory: [RelatedTopic]] = [:]
    @Published var pendingImage: UIImage?
    @Published var selectedMode: ChatMode = .contracts
    @Published var loadingStatus: String = "Analyzing..."
    @Published var showQuotaExhaustedRetry: Bool = false
    @Published var lastFailedMessage: String = ""
    @Published var lastFailedImage: UIImage? = nil
    
    // Animation state
    private var animationTask: Task<Void, Never>?
    private var pendingMessageData: (content: String, sources: [Source], followUpQuestions: [String])?
    
    // MARK: - Dependencies
    
    private let geminiService: GeminiService
    private let persistence: PersistenceController
    private let suggestionService: SuggestionService
    private let relatedTopicsService: RelatedTopicsService
    private let imageAnalysisService: ImageAnalysisService
    
    var conversation: Conversation?
    
    // MARK: - Draft Input Persistence
    
    private let draftInputKey = "chat_draft_input_text"
    
    /// Save draft input text to UserDefaults
    func saveDraftInput() {
        UserDefaults.standard.set(inputText, forKey: draftInputKey)
    }
    
    /// Restore draft input text from UserDefaults
    func restoreDraftInput() {
        if let savedInput = UserDefaults.standard.string(forKey: draftInputKey), !savedInput.isEmpty {
            inputText = savedInput
        }
    }
    
    /// Clear draft input text (called when message is successfully sent)
    private func clearDraftInput() {
        UserDefaults.standard.removeObject(forKey: draftInputKey)
    }
    
    // MARK: - Initialization
    
    init(geminiService: GeminiService? = nil, persistence: PersistenceController? = nil) {
        self.geminiService = geminiService ?? GeminiService()
        self.persistence = persistence ?? PersistenceController.shared
        self.suggestionService = SuggestionService(geminiService: self.geminiService)
        self.relatedTopicsService = RelatedTopicsService(geminiService: self.geminiService)
        self.imageAnalysisService = ImageAnalysisService(geminiService: self.geminiService)
        
        // Restore draft input on initialization
        restoreDraftInput()
    }
    
    // MARK: - Chat Management
    
    /// Start a new conversation - resets view state without creating Core Data entity
    func startNewConversation() {
        // Stop any ongoing animation
        stopAnimation()
        
        conversation = nil  // Don't create conversation until first message is sent
        messages = []
        // Don't clear inputText here - preserve draft input for user convenience
        // inputText will be cleared only when message is successfully sent
        errorMessage = nil
        followUpSuggestions = []
        relatedTopics = [:]
        selectedMode = .general
        geminiService.startNewChat()
    }
    
    /// Load an existing conversation
    func loadConversation(_ conv: Conversation) {
        conversation = conv
        messages = persistence.fetchMessages(for: conv)
        geminiService.continueChat(with: messages)
        
        // Load follow-up suggestions from the last assistant message
        if let lastAssistantMessage = messages.last(where: { $0.role == "assistant" }) {
            followUpSuggestions = lastAssistantMessage.followUpSuggestions
        } else {
            followUpSuggestions = []
        }
    }
    
    /// Send a message (optionally with image)
    func sendMessage() async {
        // Stop any ongoing animation if a new message is sent
        stopAnimation()
        
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageForSend = pendingImage
        let hasImage = imageForSend != nil
        
        // Require either text or image
        guard !text.isEmpty || hasImage else { return }
        guard !isLoading else { return }
        
        // Create temporary conversation if needed (not saved yet)
        if conversation == nil {
            conversation = persistence.createTemporaryConversation()
        }
        
        guard let conversation = conversation else { return }
        
        // Clear input and set loading
        let messageText = text.isEmpty ? (hasImage ? "Analyze this image" : "") : text
        inputText = ""
        clearDraftInput() // Clear saved draft when message is sent
        isLoading = true
        streamingResponse = ""
        errorMessage = nil
        followUpSuggestions = [] // Clear old follow-up suggestions when new message is sent
        
        // Cycling loading texts
        let loadingTexts = ["Researching case law...", "Searching legal databases...", "Verifying citations...", "Synthesizing legal analysis..."]
        var loadingIndex = 0
        loadingStatus = loadingTexts[0]
        
        let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isLoading else { return }
                loadingIndex = (loadingIndex + 1) % loadingTexts.count
                self.loadingStatus = loadingTexts[loadingIndex]
            }
        }
        
        // Add user message (this will save the conversation to Core Data)
        let userMessage = persistence.addMessage(to: conversation, content: messageText, role: "user")
        messages.append(userMessage)
        
        // Get response from Gemini with a single retry if too short
        var response: String = ""
        var sources: [Source] = []
        var followUpQuestions: [String] = []
        for attempt in 0..<2 {
            if let image = imageForSend {
                (response, sources, followUpQuestions) = await geminiService.sendMessageWithImage(messageText, image: image, mode: selectedMode)
            } else {
                (response, sources, followUpQuestions) = await geminiService.sendMessage(messageText, mode: selectedMode)
            }
            
            // Check if quota exhausted BEFORE processing response
            if response.hasPrefix("QUOTA_EXHAUSTED:") {
                pendingImage = nil
                timer.invalidate()
                isLoading = false
                streamingResponse = ""
                let userFriendlyMessage = response.replacingOccurrences(of: "QUOTA_EXHAUSTED: ", with: "")
                errorMessage = userFriendlyMessage
                
                // Store failed request for retry with fallback
                lastFailedMessage = messageText
                lastFailedImage = imageForSend
                showQuotaExhaustedRetry = true
                
                // Keep existing follow-up suggestions visible so user can still tap them
                // Clear related topics only, since they are more tightly coupled to the latest response
                relatedTopics = [:]
                
                HapticManager.shared.error()
                return
            }
            
            if !isResponseTooShort(response) || attempt == 1 {
                break
            }
        }
        
        pendingImage = nil
        
        // Always invalidate timer before any early returns
        timer.invalidate()
        
        // Reset quota exhausted retry flag on success
        showQuotaExhaustedRetry = false
        lastFailedMessage = ""
        lastFailedImage = nil
        
        // Stop any ongoing animation before processing new response
        stopAnimation()
        
        // Derive sources from inline URLs if Gemini did not return structured sources
        var resolvedSources = sources
        if resolvedSources.isEmpty {
            resolvedSources = deriveSources(from: response)
        }
        
        // Sanitize response (remove inline Sources blocks / placeholders)
        let citationPattern = #"\[\d+\]"#
        var cleanResponse = sanitizeAssistantResponse(response, hasStructuredSources: !resolvedSources.isEmpty)
        
        // FALLBACK: If we have sources but no citations in the text, attempt to inject them
        // This is a last resort - ideally Gemini should include citations
        let hasCitationsAfterSanitize = cleanResponse.range(of: citationPattern, options: .regularExpression) != nil
        if !resolvedSources.isEmpty && !hasCitationsAfterSanitize {
            cleanResponse = injectCitationsIntoText(cleanResponse, sources: resolvedSources)
        }
        
        // Fallback: if sanitization removed everything but raw response exists, keep raw
        if cleanResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            cleanResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // If still empty, set error and bail
        if cleanResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            isLoading = false
            streamingResponse = ""
            animatedResponseText = ""
            isAnimatingResponse = false
            errorMessage = "No response received. Please try again."
            showQuotaExhaustedRetry = false
            HapticManager.shared.error()
            return
        }
        
        // Stop any existing animation
        stopAnimation()
        
        // Store the full response and message data for animation
        streamingResponse = cleanResponse
        pendingMessageData = (content: cleanResponse, sources: resolvedSources, followUpQuestions: followUpQuestions)
        
        isLoading = false
        
        // Start word-by-word animation
        startWordByWordAnimation(fullText: cleanResponse)

        // Haptics and follow-up suggestions are now handled in finishAnimation()
        if let error = geminiService.error, !error.isEmpty {
            errorMessage = error
            HapticManager.shared.error()
        }
    }
    
    /// Retry last failed message with fallback model
    func retryWithFallbackModel() async {
        guard !lastFailedMessage.isEmpty || lastFailedImage != nil else { return }
        guard !isLoading else { return }
        
        // Switch to fallback model
        geminiService.useFallbackModel()
        
        // Prepare the request
        let messageText = lastFailedMessage.isEmpty ? (lastFailedImage != nil ? "Analyze this image" : "") : lastFailedMessage
        let imageForSend = lastFailedImage
        
        // Create temporary conversation if needed
        if conversation == nil {
            conversation = persistence.createTemporaryConversation()
        }
        
        guard conversation != nil else { return }
        
        // Set loading state
        isLoading = true
        streamingResponse = ""
        errorMessage = nil
        showQuotaExhaustedRetry = false
        
        // Cycling loading texts
        let loadingTexts = ["Researching case law...", "Searching legal databases...", "Verifying citations...", "Synthesizing legal analysis..."]
        var loadingIndex = 0
        loadingStatus = loadingTexts[0]
        
        let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isLoading else { return }
                loadingIndex = (loadingIndex + 1) % loadingTexts.count
                self.loadingStatus = loadingTexts[loadingIndex]
            }
        }
        
        // Get response from fallback model
        var response: String = ""
        var sources: [Source] = []
        var followUpQuestions: [String] = []
        
        if let image = imageForSend {
            (response, sources, followUpQuestions) = await geminiService.sendMessageWithImage(messageText, image: image, mode: selectedMode)
        } else {
            (response, sources, followUpQuestions) = await geminiService.sendMessage(messageText, mode: selectedMode)
        }
        
        timer.invalidate()
        
        // Check if still quota exhausted (unlikely but possible)
        if response.hasPrefix("QUOTA_EXHAUSTED:") {
            isLoading = false
            streamingResponse = ""
            errorMessage = "Fallback model is also unavailable. Please try again later."
            showQuotaExhaustedRetry = false
            HapticManager.shared.error()
            return
        }
        
        // Process response normally
        var resolvedSources = sources
        if resolvedSources.isEmpty {
            resolvedSources = deriveSources(from: response)
        }
        
        let citationPattern = #"\[\d+\]"#
        var cleanResponse = sanitizeAssistantResponse(response, hasStructuredSources: !resolvedSources.isEmpty)
        
        let hasCitationsAfterSanitize = cleanResponse.range(of: citationPattern, options: .regularExpression) != nil
        if !resolvedSources.isEmpty && !hasCitationsAfterSanitize {
            cleanResponse = injectCitationsIntoText(cleanResponse, sources: resolvedSources)
        }
        
        if cleanResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            cleanResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        if cleanResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            isLoading = false
            streamingResponse = ""
            errorMessage = "No response received. Please try again."
            HapticManager.shared.error()
            return
        }
        
        // Stop any ongoing animation
        stopAnimation()
        
        // Store the full response and message data for animation
        streamingResponse = cleanResponse
        pendingMessageData = (content: cleanResponse, sources: resolvedSources, followUpQuestions: followUpQuestions)
        
        isLoading = false
        showQuotaExhaustedRetry = false
        lastFailedMessage = ""
        lastFailedImage = nil
        
        // Start word-by-word animation
        startWordByWordAnimation(fullText: cleanResponse)
        
        // Switch back to primary model for next request
        geminiService.usePrimaryModel()
    }
    
    /// Show source preview
    func showSource(_ source: Source) {
        selectedSource = source
        showSourcePreview = true
    }
    
    /// Get the current streaming text from Gemini service
    var currentStreamingText: String {
        geminiService.currentResponse
    }
    
    /// Fallback function to inject citations into text if Gemini didn't include them
    /// This is a rough approximation - ideally Gemini should include citations
    private func injectCitationsIntoText(_ text: String, sources: [Source]) -> String {
        guard !sources.isEmpty else { return text }
        
        var result = text
        
        // Simple approach: Add citations at paragraph boundaries or after key sentences
        // Split into paragraphs
        let paragraphs = text.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        guard !paragraphs.isEmpty else {
            // If no paragraphs, try adding citations to the end of the text
            var citationString = ""
            for (index, _) in sources.enumerated() {
                citationString += "[\(index + 1)]"
            }
            return text + citationString
        }
        
        var modifiedParagraphs: [String] = []
        var sourceIndex = 0
        
        // Distribute citations across paragraphs
        let citationsPerParagraph = max(1, sources.count / paragraphs.count)
        
        for (_, paragraph) in paragraphs.enumerated() {
            var modifiedParagraph = paragraph
            
            // Check if paragraph already has citations
            let hasCitations = paragraph.range(of: #"\[\d+\]"#, options: .regularExpression) != nil
            
            if !hasCitations {
                // Add citations to the end of this paragraph
                var citationsToAdd = ""
                let startSource = sourceIndex
                let endSource = min(sourceIndex + citationsPerParagraph, sources.count)
                
                for i in startSource..<endSource {
                    citationsToAdd += "[\(i + 1)]"
                }
                
                if !citationsToAdd.isEmpty {
                    // Find last sentence ending
                    if let lastPeriod = paragraph.lastIndex(of: ".") ?? paragraph.lastIndex(of: "!") ?? paragraph.lastIndex(of: "?") {
                        let insertPos = paragraph.index(after: lastPeriod)
                        modifiedParagraph.insert(contentsOf: citationsToAdd, at: insertPos)
                    } else {
                        // No sentence ending, append to end
                        modifiedParagraph += citationsToAdd
                    }
                    
                    sourceIndex = endSource
                }
            } else {
                // Paragraph already has citations, skip
            }
            
            modifiedParagraphs.append(modifiedParagraph)
        }
        
        result = modifiedParagraphs.joined(separator: "\n\n")
        
        // If we still have sources left, add them to the end
        if sourceIndex < sources.count {
            var remainingCitations = ""
            for i in sourceIndex..<sources.count {
                remainingCitations += "[\(i + 1)]"
            }
            result += remainingCitations
        }
        
        return result
    }
    
    private func sanitizeAssistantResponse(_ text: String, hasStructuredSources: Bool) -> String {
        var result = text
        
        // Remove the entire "Sources" section using comprehensive regex pattern
        // Pattern matches "Sources" or "Sources:" followed by everything to end of string
        // [\s\S] matches any character including newlines (more reliable than .*)
        let sourcesPattern = #"(?i)(^|\n)\s*Sources?[:]?[\s\S]*$"#
        result = result.replacingOccurrences(of: sourcesPattern, with: "$1", options: .regularExpression)
        
        // Fallback: If still present, try removing everything after "Sources" on same line or next
        if result.contains("Sources") || result.contains("sources") {
            // More aggressive: remove from any "Sources" to end
            if let sourcesRange = result.range(of: #"(?i)Sources?[:]?[\s\S]*$"#, options: .regularExpression) {
                let startIndex = sourcesRange.lowerBound
                // Check if we should include the newline before "Sources"
                if startIndex > result.startIndex && result[result.index(before: startIndex)] == "\n" {
                    result = String(result[..<result.index(before: startIndex)])
                } else {
                    result = String(result[..<startIndex])
                }
            }
        }
        
        // Remove "(URL unavailable)" placeholders
        result = result.replacingOccurrences(of: "(?i)URL unavailable", with: "", options: .regularExpression)
        
        // Remove "URL:" patterns that might be left over
        result = result.replacingOccurrences(of: #"(?i)\bURL:\s*"#, with: "", options: .regularExpression)
        
        // Collapse double spaces/newlines
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func deriveSources(from text: String) -> [Source] {
        // Extract full URLs
        let urlPattern = ##"https?://[A-Za-z0-9\.\-/_\?\=\#%&+:;,]+[A-Za-z0-9/#]"##
        var seen = Set<String>()
        var sources: [Source] = []
        
        if let regex = try? NSRegularExpression(pattern: urlPattern, options: []) {
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: text.utf16.count))
            for match in matches {
                if let range = Range(match.range, in: text) {
                    var urlString = String(text[range])
                    urlString = urlString.trimmingCharacters(in: CharacterSet(charactersIn: ".,);]"))
                    guard !urlString.isEmpty, seen.insert(urlString).inserted else { continue }
                    
                    let title = URL(string: urlString)?.host ?? urlString
                    sources.append(Source(title: title, url: urlString, snippet: nil, favicon: nil))
                }
            }
        }
        
        // Extract bare domains and promote to https://domain if not already present
        let domainPattern = ##"\b([A-Za-z0-9-]+\.[A-Za-z0-9\.-]{2,})\b"##
        if let domainRegex = try? NSRegularExpression(pattern: domainPattern, options: []) {
            let matches = domainRegex.matches(in: text, range: NSRange(location: 0, length: text.utf16.count))
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    let domain = String(text[range]).trimmingCharacters(in: CharacterSet(charactersIn: ".,);]"))
                    guard !domain.isEmpty else { continue }
                    let normalized = domain.lowercased()
                    let urlString = "https://\(normalized)"
                    guard seen.insert(urlString).inserted else { continue }
                    sources.append(Source(title: normalized, url: urlString, snippet: nil, favicon: nil))
                }
            }
        }
        
        return sources
    }
    
    private func isResponseTooShort(_ text: String) -> Bool {
        let wordCount = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        let sentenceCount = text.split(whereSeparator: { ".!?".contains($0) }).count
        return wordCount < 60 || sentenceCount < 3
    }
    
    // MARK: - Message Actions
    
    /// Copy message content to clipboard
    func copyMessage(_ message: Message) {
        UIPasteboard.general.string = message.content
    }
    
    /// Share message content
    func shareMessage(_ message: Message) -> String {
        var shareText = message.content ?? ""
        
        let sources = message.sources
        if !sources.isEmpty {
            shareText += "\n\nSources:\n"
            for (index, source) in sources.enumerated() {
                shareText += "[\(index + 1)] \(source.title): \(source.url)\n"
            }
        }
        
        return shareText
    }
    
    /// Toggle bookmark for current conversation
    func toggleBookmark() {
        guard let conversation = conversation else { return }
        persistence.toggleBookmark(conversation)
        // Refresh the conversation object to ensure Core Data changes are reflected
        if let context = conversation.managedObjectContext {
            context.refresh(conversation, mergeChanges: true)
        }
        objectWillChange.send()
    }
    
    /// Check if current conversation is bookmarked
    var isBookmarked: Bool {
        conversation?.isBookmarked ?? false
    }
    
    /// Handle follow-up suggestion tap
    func selectFollowUpSuggestion(_ suggestion: String) {
        inputText = suggestion
    }
    
    /// Handle related topic tap
    func selectRelatedTopic(_ topic: RelatedTopic) {
        inputText = "Tell me more about \(topic.title)"
    }
    
    /// Set pending image to send with next message
    func setPendingImage(_ image: UIImage?) {
        pendingImage = image
    }
    
    // MARK: - Word-by-Word Animation
    
    /// Split text into words, treating citations like [1] as single units
    private func splitIntoWords(_ text: String) -> [String] {
        var words: [String] = []
        var currentWord = ""
        var i = text.startIndex
        
        while i < text.endIndex {
            let char = text[i]
            
            // Check if we're starting a citation [1], [2], etc.
            if char == "[" {
                // If we have accumulated text, add it as a word
                if !currentWord.isEmpty {
                    words.append(currentWord)
                    currentWord = ""
                }
                
                // Find the closing bracket
                var citation = "["
                i = text.index(after: i)
                while i < text.endIndex && text[i] != "]" {
                    citation.append(text[i])
                    i = text.index(after: i)
                }
                
                // Include the closing bracket if found
                if i < text.endIndex {
                    citation.append(text[i])
                    words.append(citation)
                    i = text.index(after: i)
                    
                    // Check for consecutive citations like [1][2][3]
                    // Continue reading if next char is also '['
                    while i < text.endIndex && text[i] == "[" {
                        var nextCitation = "["
                        i = text.index(after: i)
                        while i < text.endIndex && text[i] != "]" {
                            nextCitation.append(text[i])
                            i = text.index(after: i)
                        }
                        if i < text.endIndex {
                            nextCitation.append(text[i])
                            words.append(nextCitation)
                            i = text.index(after: i)
                        } else {
                            // No closing bracket, break
                            break
                        }
                    }
                } else {
                    // No closing bracket, treat as regular text
                    currentWord = citation
                }
            } else if char.isWhitespace || char.isNewline {
                // Whitespace - add current word if any
                if !currentWord.isEmpty {
                    words.append(currentWord)
                    currentWord = ""
                }
                // Add whitespace as a separate element to preserve spacing
                // But combine consecutive whitespace to avoid too many animation steps
                if words.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                    // Merge with previous whitespace
                    words[words.count - 1] += String(char)
                } else {
                    words.append(String(char))
                }
                i = text.index(after: i)
            } else {
                // Regular character
                currentWord.append(char)
                i = text.index(after: i)
            }
        }
        
        // Add any remaining word
        if !currentWord.isEmpty {
            words.append(currentWord)
        }
        
        return words
    }
    
    /// Start word-by-word animation
    private func startWordByWordAnimation(fullText: String) {
        // Cancel any existing animation
        stopAnimation()
        
        let words = splitIntoWords(fullText)
        guard !words.isEmpty else {
            // No words to animate, add message immediately
            finishAnimation()
            return
        }
        
        isAnimatingResponse = true
        animatedResponseText = ""
        
        // Create animation task
        animationTask = Task { @MainActor in
            for (_, word) in words.enumerated() {
                // Check if task was cancelled
                if Task.isCancelled {
                    break
                }
                
                // Append word to animated text
                animatedResponseText += word
                
                // Wait before next word (30-50ms per word)
                // Slightly faster for whitespace, normal for words
                let delay: UInt64 = word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 10_000_000 : 40_000_000 // 10ms for whitespace, 40ms for words
                
                try? await Task.sleep(nanoseconds: delay)
            }
            
            // Animation complete
            if !Task.isCancelled {
                finishAnimation()
            }
        }
    }
    
    /// Stop the current animation and show full text immediately
    private func stopAnimation() {
        animationTask?.cancel()
        animationTask = nil
        
        if isAnimatingResponse {
            // Show full text immediately
            animatedResponseText = streamingResponse
            finishAnimation()
        }
    }
    
    /// Finish animation and add message to conversation
    private func finishAnimation() {
        guard let messageData = pendingMessageData,
              let conversation = conversation else {
            isAnimatingResponse = false
            animatedResponseText = ""
            streamingResponse = ""
            pendingMessageData = nil
            return
        }
        
        // Add assistant message with sources and follow-up suggestions
        let assistantMessage = persistence.addMessage(
            to: conversation,
            content: messageData.content,
            role: "assistant",
            sources: messageData.sources,
            followUpSuggestions: messageData.followUpQuestions
        )
        
        messages.append(assistantMessage)
        
        // Clear animation state
        isAnimatingResponse = false
        animatedResponseText = ""
        streamingResponse = ""
        pendingMessageData = nil
        
        // Haptics for success
        HapticManager.shared.success()
        
        // Use follow-up questions from the response
        followUpSuggestions = messageData.followUpQuestions
        
        // Generate related topics separately
        let messageDataForTopics = messages.map { MessageData(role: $0.role ?? "", content: $0.content ?? "") }
        Task {
            async let topicsTask = relatedTopicsService.findRelatedTopics(
                conversationHistory: messageDataForTopics,
                lastResponse: messageData.content
            )
            
            relatedTopics = await topicsTask
        }
    }
}

// MARK: - Preview Helper
extension ChatViewModel {
    static var preview: ChatViewModel {
        let vm = ChatViewModel(persistence: .preview)
        // Load preview data
        let conversations = PersistenceController.preview.fetchConversations()
        if let firstConversation = conversations.first {
            vm.loadConversation(firstConversation)
        }
        return vm
    }
}
