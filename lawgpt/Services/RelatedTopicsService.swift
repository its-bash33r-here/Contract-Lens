//
//  RelatedTopicsService.swift
//  lawgpt
//
//  Created by Bash33r on 01/12/25.
//

import Foundation

/// Represents a related legal topic
struct RelatedTopic: Identifiable, Hashable {
    let id: UUID
    let title: String
    let description: String?
    let category: TopicCategory
    let sourceCount: Int
    
    init(id: UUID = UUID(), title: String, description: String? = nil, category: TopicCategory, sourceCount: Int = 0) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.sourceCount = sourceCount
    }
}

enum TopicCategory: String, CaseIterable {
    case symptoms = "Symptoms"
    case treatment = "Treatment"
    case causes = "Causes"
    case prevention = "Prevention"
    case research = "Research"
    case diagnosis = "Diagnosis"
    case complications = "Complications"
    
    var icon: String {
        switch self {
        case .symptoms: return "heart.text.square"
        case .treatment: return "pills"
        case .causes: return "magnifyingglass"
        case .prevention: return "shield"
        case .research: return "book"
        case .diagnosis: return "stethoscope"
        case .complications: return "exclamationmark.triangle"
        }
    }
}

/// Service for finding related legal topics
@MainActor
class RelatedTopicsService {
    private let geminiService: GeminiService
    
    init(geminiService: GeminiService? = nil) {
        self.geminiService = geminiService ?? GeminiService()
    }
    
    /// Extract related topics from conversation
    func findRelatedTopics(
        conversationHistory: [MessageData],
        lastResponse: String
    ) async -> [TopicCategory: [RelatedTopic]] {
        // Extract key legal concepts
        let concepts = extractKeyConcepts(from: conversationHistory, lastResponse: lastResponse)
        
        // Generate related topics for each category
        var topicsByCategory: [TopicCategory: [RelatedTopic]] = [:]
        
        for category in TopicCategory.allCases {
            let topics = await generateTopicsForCategory(
                category: category,
                concepts: concepts,
                conversationContext: buildContext(from: conversationHistory, lastResponse: lastResponse)
            )
            if !topics.isEmpty {
                topicsByCategory[category] = topics
            }
        }
        
        return topicsByCategory
    }
    
    private func extractKeyConcepts(from history: [MessageData], lastResponse: String) -> [String] {
        // Simple extraction - in production, could use NLP
        let allText = (history.map { $0.content } + [lastResponse]).joined(separator: " ")
        
        // Extract legal terms (simplified - would use proper NLP in production)
        let words = allText.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 5 } // Filter short words
            .prefix(20) // Limit to top concepts
        
        return Array(words)
    }
    
    private func buildContext(from history: [MessageData], lastResponse: String) -> String {
        var context = ""
        
        let recentMessages = history.suffix(4)
        for message in recentMessages {
            let role = message.role == "user" ? "User" : "Assistant"
            context += "\(role): \(message.content)\n\n"
        }
        
        context += "Last Response: \(lastResponse)"
        
        return context
    }
    
    private func generateTopicsForCategory(
        category: TopicCategory,
        concepts: [String],
        conversationContext: String
    ) async -> [RelatedTopic] {
        let prompt = """
        Based on the following legal conversation, generate 3-5 related topics in the category: \(category.rawValue)
        
        Conversation context:
        \(conversationContext)
        
        Key concepts: \(concepts.joined(separator: ", "))
        
        Category: \(category.rawValue)
        
        Guidelines:
        1. Topics should be directly related to the legal discussion
        2. Each topic should have a clear title (under 10 words)
        3. Include a brief description if helpful (under 20 words)
        4. Focus on authoritative legal information
        5. Return topics in format: "Title | Description" (one per line, description optional)
        
        Generate related \(category.rawValue.lowercased()) topics:
        """
        
        // Use Gemini to generate related topics (ignore follow-up questions from this call)
        let (response, sources, _) = await geminiService.sendMessage(prompt)
        
        // Parse topics from response
        let topics = parseTopics(from: response, category: category, sourceCount: sources.count)
        
        return Array(topics.prefix(5))
    }
    
    private func parseTopics(from response: String, category: TopicCategory, sourceCount: Int) -> [RelatedTopic] {
        let lines = response.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var topics: [RelatedTopic] = []
        
        for line in lines {
            // Parse "Title | Description" format
            let parts = line.components(separatedBy: "|")
            let title = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? line
            let description = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : nil
            
            // Clean up title (remove numbering, bullets)
            let cleanedTitle = title
                .replacingOccurrences(of: "^\\d+[.)]\\s*", with: "", options: .regularExpression)
                .replacingOccurrences(of: "^[-*]\\s*", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !cleanedTitle.isEmpty && cleanedTitle.count > 5 {
                topics.append(RelatedTopic(
                    title: cleanedTitle,
                    description: description,
                    category: category,
                    sourceCount: sourceCount
                ))
            }
        }
        
        return topics
    }
}
