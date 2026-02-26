//
//  HistoryViewModel.swift
//  lawgpt
//
//  Created by Bash33r on 01/12/25.
//

import Foundation
import SwiftUI
import CoreData
import Combine

/// ViewModel for managing conversation history
@MainActor
class HistoryViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var conversations: [Conversation] = []
    @Published var searchText: String = ""
    @Published var showBookmarkedOnly: Bool = false
    @Published var isLoading: Bool = false
    @Published var suppressedConversationIds: Set<UUID> = []
    
    // MARK: - Dependencies
    
    private let persistence: PersistenceController
    private var pendingDeleteTasks: [UUID: DispatchWorkItem] = [:]
    
    // MARK: - Computed Properties
    
    var filteredConversations: [Conversation] {
        var result = conversations
        
        // Filter by bookmark
        if showBookmarkedOnly {
            result = result.filter { $0.isBookmarked }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { conversation in
                // Check title
                if let title = conversation.title,
                   title.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                
                // Check message content
                if let messages = conversation.messages as? Set<Message> {
                    return messages.contains { message in
                        message.content?.localizedCaseInsensitiveContains(searchText) ?? false
                    }
                }
                
                return false
            }
        }
        
        // Sort: bookmarked conversations first, then by updatedAt descending
        if !showBookmarkedOnly {
            result = result.sorted { conversation1, conversation2 in
                // If one is bookmarked and the other isn't, bookmarked comes first
                if conversation1.isBookmarked != conversation2.isBookmarked {
                    return conversation1.isBookmarked
                }
                
                // If both have same bookmark status, sort by updatedAt (most recent first)
                let date1 = conversation1.updatedAt ?? conversation1.createdAt ?? Date.distantPast
                let date2 = conversation2.updatedAt ?? conversation2.createdAt ?? Date.distantPast
                return date1 > date2
            }
        } else {
            // When showing only bookmarked, just sort by updatedAt
            result = result.sorted { conversation1, conversation2 in
                let date1 = conversation1.updatedAt ?? conversation1.createdAt ?? Date.distantPast
                let date2 = conversation2.updatedAt ?? conversation2.createdAt ?? Date.distantPast
                return date1 > date2
            }
        }
        
        // Hide suppressed (pending delete) conversations
        result = result.filter { convo in
            guard let id = convo.id else { return true }
            return !suppressedConversationIds.contains(id)
        }
        
        return result
    }
    
    // MARK: - Initialization
    
    init(persistence: PersistenceController? = nil) {
        self.persistence = persistence ?? PersistenceController.shared
        loadConversations()
    }
    
    // MARK: - Data Operations
    
    /// Load all conversations
    func loadConversations() {
        isLoading = true
        // Cleanup empty conversations before fetching
        persistence.cleanupEmptyConversations()
        conversations = persistence.fetchConversations()
        isLoading = false
    }
    
    /// Search conversations
    func search() {
        if searchText.isEmpty {
            loadConversations()
        } else {
            conversations = persistence.searchConversations(query: searchText)
        }
    }
    
    /// Delete a conversation
    func deleteConversation(_ conversation: Conversation) {
        persistence.deleteConversation(conversation)
        loadConversations()
    }
    
    /// Schedule a delete with undo window
    func scheduleDelete(_ conversation: Conversation, delay: TimeInterval = 3) {
        guard let convoId = conversation.id else { return }
        
        // Remove any existing pending task for this conversation
        cancelScheduledDelete(conversationId: convoId)
        
        suppressedConversationIds.insert(convoId)
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingDeleteTasks[convoId] = nil
            self.suppressedConversationIds.remove(convoId)
            self.deleteConversation(conversation)
        }
        pendingDeleteTasks[convoId] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
    
    /// Cancel pending delete (undo)
    func cancelScheduledDelete(conversationId: UUID) {
        if let work = pendingDeleteTasks[conversationId] {
            work.cancel()
            pendingDeleteTasks[conversationId] = nil
        }
        suppressedConversationIds.remove(conversationId)
    }
    
    /// Finalize if still pending (used when toast hides)
    func finalizeScheduledDeleteIfNeeded(conversationId: UUID) {
        guard let work = pendingDeleteTasks[conversationId] else { return }
        // If task still pending, let it run now
        if !work.isCancelled {
            work.perform()
        }
    }
    
    /// Toggle bookmark for a conversation
    func toggleBookmark(_ conversation: Conversation) {
        persistence.toggleBookmark(conversation)
        objectWillChange.send()
    }
    
    /// Get preview text for a conversation (first user message)
    func previewText(for conversation: Conversation) -> String {
        guard let messages = conversation.messages as? Set<Message> else {
            return "No messages"
        }
        
        let sortedMessages = messages.sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }
        
        if let firstUserMessage = sortedMessages.first(where: { $0.role == "user" }) {
            return firstUserMessage.content ?? "No content"
        }
        
        return "No messages"
    }
    
    /// Format date for display
    func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
}

// MARK: - Preview Helper
extension HistoryViewModel {
    static var preview: HistoryViewModel {
        let vm = HistoryViewModel(persistence: .preview)
        return vm
    }
}
