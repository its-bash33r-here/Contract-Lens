//
//  ConversationThread.swift
//  lawgpt
//
//  Created by Bash33r on 01/12/25.
//

import Foundation
import CoreData

/// Thread manager for grouping related conversations
/// Uses UserDefaults to store thread relationships (since Core Data schema doesn't include threadId)
class ConversationThreadManager {
    static let shared = ConversationThreadManager()
    
    private let threadKeyPrefix = "conversation_thread_"
    
    private init() {}
    
    /// Get thread ID for a conversation
    func getThreadId(for conversationId: UUID) -> String? {
        UserDefaults.standard.string(forKey: threadKeyPrefix + conversationId.uuidString)
    }
    
    /// Set thread ID for a conversation
    func setThreadId(_ threadId: String?, for conversationId: UUID) {
        let key = threadKeyPrefix + conversationId.uuidString
        if let threadId = threadId {
            UserDefaults.standard.set(threadId, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
    
    /// Get all conversations in the same thread
    func getThreadConversations(threadId: String, in context: NSManagedObjectContext) -> [Conversation] {
        let request: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        let allConversations = (try? context.fetch(request)) ?? []
        
        return allConversations.filter { conversation in
            guard let id = conversation.id else { return false }
            return getThreadId(for: id) == threadId
        }.sorted { ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) }
    }
    
    /// Create a new thread ID
    func generateThreadId() -> String {
        UUID().uuidString
    }
    
    /// Assign conversation to a thread
    func assignToThread(_ threadId: String?, conversationId: UUID) {
        setThreadId(threadId, for: conversationId)
    }
}

/// Extension for Conversation to support threading
extension Conversation {
    /// Thread identifier for grouping related conversations
    var threadId: String? {
        get {
            guard let id = id else { return nil }
            return ConversationThreadManager.shared.getThreadId(for: id)
        }
        set {
            guard let id = id else { return }
            ConversationThreadManager.shared.setThreadId(newValue, for: id)
        }
    }
    
    /// Get all conversations in the same thread
    func getThreadConversations() -> [Conversation] {
        guard let threadId = threadId,
              let context = managedObjectContext else {
            return [self]
        }
        return ConversationThreadManager.shared.getThreadConversations(threadId: threadId, in: context)
    }
    
    /// Create or assign to a thread
    func assignToThread(_ threadId: String?) {
        self.threadId = threadId
    }
    
    /// Create a new thread and assign this conversation to it
    func createNewThread() {
        self.threadId = ConversationThreadManager.shared.generateThreadId()
    }
}
