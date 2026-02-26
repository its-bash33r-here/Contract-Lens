//
//  SuggestionService.swift
//  lawgpt
//
//  Created by Bash33r on 01/12/25.
//

import Foundation

/// Service for generating contextual follow-up question suggestions
@MainActor
class SuggestionService {
    private let geminiService: GeminiService
    
    init(geminiService: GeminiService? = nil) {
        self.geminiService = geminiService ?? GeminiService()
    }
    
    /// Generate follow-up questions based on conversation context
    func generateFollowUpQuestions(
        conversationHistory: [MessageData],
        lastResponse: String
    ) async -> [String] {
        // Build context from conversation
        let context = buildContext(from: conversationHistory, lastResponse: lastResponse)
        
        // Create prompt for generating suggestions
        let prompt = """
        Based on the following legal conversation, generate 3-5 concise, educational follow-up questions that help users learn more about the legal topic.
        
        Conversation context:
        \(context)
        
        CRITICAL GUIDELINES:
        1. Questions MUST be educational and informational, NOT personal or asking about the user's specific situation
        2. Questions should explore the legal topic itself, not ask the user about their case
        3. Good examples (EDUCATIONAL):
           - "What are the elements of a valid contract?"
           - "How is breach of contract proven?"
           - "What are the remedies available for breach of contract?"
           - "What is the statute of limitations for contract claims?"
           - "What are common defenses to breach of contract?"
        4. BAD examples (PERSONAL - DO NOT USE):
           - "Are you being sued?" ❌
           - "Do you have a case?" ❌
           - "What is your specific situation?" ❌
           - "What should you do?" ❌
        5. Questions should be about the legal topic/concept itself
        6. Keep questions concise (under 15 words each)
        7. Focus on educational content that helps users understand the legal information better
        8. Return only the questions, one per line, without numbering or bullets
        
        Generate educational follow-up questions:
        """
        
        // Use Gemini to generate suggestions
        let (response, _, _) = await geminiService.sendMessage(prompt, mode: .general)
        
        // Check if response is an error (quota exhaustion, etc.) - don't parse errors as questions
        if response.hasPrefix("QUOTA_EXHAUSTED:") || response.hasPrefix("LawGPT Pro subscription") || response.hasPrefix("I apologize, but I encountered an error") {
            return []
        }
        
        // Parse response into array of questions
        let questions = parseQuestions(from: response)
        
        // Return up to 5 questions
        return Array(questions.prefix(5))
    }
    
    private func buildContext(from history: [MessageData], lastResponse: String) -> String {
        var context = ""
        
        // Include last few messages for context
        let recentMessages = history.suffix(4)
        for message in recentMessages {
            let role = message.role == "user" ? "User" : "Assistant"
            context += "\(role): \(message.content)\n\n"
        }
        
        context += "Last Response: \(lastResponse)"
        
        return context
    }
    
    private func parseQuestions(from response: String) -> [String] {
        // Split by newlines and clean up
        let lines = response.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Remove common prefixes like "1.", "-", "*", etc.
        let cleaned = lines.map { line in
            line.replacingOccurrences(of: "^\\d+[.)]\\s*", with: "", options: .regularExpression)
                .replacingOccurrences(of: "^[-*]\\s*", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter { !$0.isEmpty && $0.count > 10 } // Filter out very short lines
        .filter { !$0.hasPrefix("QUOTA_EXHAUSTED:") } // Filter out quota exhaustion errors
        .filter { !$0.hasPrefix("LawGPT Pro subscription") } // Filter out subscription errors
        .filter { !$0.hasPrefix("I apologize, but I encountered an error") } // Filter out generic errors
        
        return cleaned
    }
}
