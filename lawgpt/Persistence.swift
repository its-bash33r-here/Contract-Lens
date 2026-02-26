//
//  Persistence.swift
//  lawgpt
//
//  Created by Bash33r on 01/12/25.
//

import CoreData

struct PersistenceController {
    // Thread-safe singleton initialization
    // Swift's static let is already thread-safe, but we ensure it's called properly
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample conversation for previews
        let conversation = Conversation(context: viewContext)
        conversation.id = UUID()
        conversation.title = "What are the symptoms of diabetes?"
        conversation.createdAt = Date()
        conversation.updatedAt = Date()
        conversation.isBookmarked = false
        
        // Add sample messages
        let userMessage = Message(context: viewContext)
        userMessage.id = UUID()
        userMessage.content = "What are the common symptoms of type 2 diabetes?"
        userMessage.role = "user"
        userMessage.timestamp = Date()
        userMessage.conversation = conversation
        
        let assistantMessage = Message(context: viewContext)
        assistantMessage.id = UUID()
        assistantMessage.content = "Type 2 diabetes often develops gradually and symptoms may include:\n\n1. **Increased thirst** - You may feel unusually thirsty [1]\n2. **Frequent urination** - Especially at night [1]\n3. **Increased hunger** - Even after eating [2]\n4. **Fatigue** - Feeling tired more often than usual [2]\n5. **Blurred vision** - High blood sugar can affect your eyes [3]\n6. **Slow-healing sores** - Cuts and bruises heal slowly [3]\n7. **Numbness or tingling** - Usually in hands or feet [1]\n\nIf you experience these symptoms, consult a healthcare provider for proper diagnosis."
        assistantMessage.role = "assistant"
        assistantMessage.timestamp = Date().addingTimeInterval(1)
        assistantMessage.conversation = conversation
        
        // Add sample sources
        let sources: [Source] = [
            Source(title: "Diabetes Symptoms", url: "https://www.mayoclinic.org/diseases-conditions/diabetes/symptoms-causes", snippet: "Diabetes symptoms vary depending on how much your blood sugar is elevated."),
            Source(title: "Type 2 Diabetes Overview", url: "https://www.cdc.gov/diabetes/basics/type2.html", snippet: "Type 2 diabetes is the most common form of diabetes."),
            Source(title: "Diabetes Signs and Symptoms", url: "https://www.who.int/news-room/fact-sheets/detail/diabetes", snippet: "The World Health Organization provides comprehensive information on diabetes.")
        ]
        assistantMessage.sourcesJSON = sources.toJSONString()
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("⚠️ Preview Core Data save error: \(nsError), \(nsError.userInfo)")
            // In preview context, we can continue without crashing
        }
        return result
    }()

    let container: NSPersistentContainer
    
    /// Safely get viewContext - ensures coordinator exists before returning
    var safeViewContext: NSManagedObjectContext {
        let context = container.viewContext
        // Verify coordinator exists (stores must be loading or loaded)
        if context.persistentStoreCoordinator == nil {
            print("⚠️ WARNING: Accessing viewContext before coordinator is ready")
        }
        return context
    }

    init(inMemory: Bool = false) {
        // CRITICAL FOR TESTFLIGHT: Verify Core Data model and classes exist
        let containerName = "lawgpt"
        
        // Verify model file exists in bundle (common TestFlight issue)
        var modelFound = false
        if let modelURL = Bundle.main.url(forResource: containerName, withExtension: "momd") {
            print("✅ Found Core Data model: \(modelURL.lastPathComponent)")
            modelFound = true
        } else if let modelURL = Bundle.main.url(forResource: containerName, withExtension: "mom") {
            print("✅ Found Core Data model (mom): \(modelURL.lastPathComponent)")
            modelFound = true
        } else {
            print("❌ CRITICAL ERROR: Core Data model file NOT FOUND in bundle!")
            print("   Looking for: \(containerName).momd or \(containerName).mom")
            print("   The app will crash if model file is missing!")
            print("   SOLUTION: Ensure lawgpt.xcdatamodeld is included in target's Build Phases")
        }
        
        // Verify Core Data entity classes exist (auto-generated from model)
        // These must exist at runtime or the app will crash
        // Check both module-prefixed and non-prefixed class names
        let conversationClassExists = NSClassFromString("lawgpt.Conversation") != nil || 
                                     NSClassFromString("Conversation") != nil ||
                                     (NSClassFromString("_TtC6lawgpt12Conversation") != nil) // Swift mangled name
        let messageClassExists = NSClassFromString("lawgpt.Message") != nil || 
                                NSClassFromString("Message") != nil ||
                                (NSClassFromString("_TtC6lawgpt7Message") != nil) // Swift mangled name
        
        if !conversationClassExists {
            print("❌ CRITICAL: Conversation class not found! This WILL cause crashes.")
            print("   Core Data code generation may have failed.")
        }
        if !messageClassExists {
            print("❌ CRITICAL: Message class not found! This WILL cause crashes.")
            print("   Core Data code generation may have failed.")
        }
        
        if modelFound && conversationClassExists && messageClassExists {
            print("✅ Core Data classes verified - safe to proceed")
        } else {
            print("⚠️ WARNING: Core Data setup incomplete - app may crash on first Core Data operation")
        }
        
        // Initialize container - this will create even if model is missing
        // but will fail when loading stores (which we handle)
        container = NSPersistentContainer(name: containerName)
        
        // Safety check: Ensure we have at least one store description
        if container.persistentStoreDescriptions.isEmpty {
            print("❌ CRITICAL: No persistent store descriptions - Core Data cannot function")
        }
        
        if inMemory {
            if let storeDescription = container.persistentStoreDescriptions.first {
                storeDescription.url = URL(fileURLWithPath: "/dev/null")
            }
        }
        
        // Configure store options for better error recovery
        if let storeDescription = container.persistentStoreDescriptions.first {
            storeDescription.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            storeDescription.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        }
        
        // Capture container in local variable to avoid capturing self in escaping closure
        let persistentContainer = container
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Log the error but don't crash - allow app to continue
                print("❌ Core Data Error: \(error.localizedDescription)")
                print("   Error domain: \(error.domain), code: \(error.code)")
                print("   User info: \(error.userInfo)")
                
                // Attempt recovery: delete and recreate the store
                if let url = storeDescription.url, !inMemory {
                    do {
                        // Get the persistent store coordinator
                        let coordinator = persistentContainer.persistentStoreCoordinator
                        
                        // Try to destroy the corrupted store
                        try coordinator.destroyPersistentStore(
                            at: url,
                            ofType: storeDescription.type,
                            options: nil
                        )
                        
                        // Try loading again after deletion
                        persistentContainer.loadPersistentStores { (storeDescription, retryError) in
                            if let retryError = retryError as NSError? {
                                print("❌ Core Data Recovery Failed: \(retryError.localizedDescription)")
                                print("   The app will continue but data persistence may be limited")
                                // App will continue - Core Data operations will fail gracefully
                            } else {
                                print("✅ Core Data Recovery Successful - store recreated")
                            }
                        }
                    } catch let destroyError {
                        print("❌ Failed to destroy corrupted store: \(destroyError.localizedDescription)")
                        // App will continue - user can still use the app
                    }
                } else {
                    print("⚠️ Core Data error but continuing (in-memory mode or no URL)")
                }
            } else {
                print("✅ Core Data loaded successfully")
            }
        })
        
        // Configure view context safely
        // Note: viewContext is available immediately, but won't work until stores are loaded
        container.viewContext.automaticallyMergesChangesFromParent = true
        // Set merge policy to handle conflicts gracefully
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        // Disable undo for better performance
        container.viewContext.undoManager = nil
    }
    
    // MARK: - Conversation CRUD Operations
    
    /// Create a new conversation
    func createConversation(title: String = "New Chat") -> Conversation {
        let context = container.viewContext
        let conversation = Conversation(context: context)
        conversation.id = UUID()
        conversation.title = title
        conversation.createdAt = Date()
        conversation.updatedAt = Date()
        conversation.isBookmarked = false
        saveContext()
        return conversation
    }
    
    /// Create a temporary conversation in memory without saving to Core Data
    /// This conversation will be saved when the first message is added
    func createTemporaryConversation(title: String = "New Chat") -> Conversation {
        let context = container.viewContext
        let conversation = Conversation(context: context)
        conversation.id = UUID()
        conversation.title = title
        conversation.createdAt = Date()
        conversation.updatedAt = Date()
        conversation.isBookmarked = false
        // Don't save yet - will be saved when first message is added
        return conversation
    }
    
    /// Fetch all conversations sorted by most recent
    /// Only returns conversations that have at least one message
    func fetchConversations(bookmarkedOnly: Bool = false) -> [Conversation] {
        let context = container.viewContext
        let request: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Conversation.updatedAt, ascending: false)]
        
        // Build predicate to filter empty conversations and optionally bookmarked
        var predicateParts: [NSPredicate] = []
        
        // Always exclude empty conversations (no messages)
        predicateParts.append(NSPredicate(format: "messages.@count > 0"))
        
        // Optional: filter by bookmarked
        if bookmarkedOnly {
            predicateParts.append(NSPredicate(format: "isBookmarked == YES"))
        }
        
        // Combine predicates
        if predicateParts.count > 1 {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicateParts)
        } else {
            request.predicate = predicateParts.first
        }
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching conversations: \(error)")
            return []
        }
    }
    
    /// Search conversations by title or message content
    /// Only returns conversations that have at least one message
    func searchConversations(query: String) -> [Conversation] {
        let context = container.viewContext
        let request: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Conversation.updatedAt, ascending: false)]
        
        var predicateParts: [NSPredicate] = []
        
        // Always exclude empty conversations (no messages)
        predicateParts.append(NSPredicate(format: "messages.@count > 0"))
        
        if !query.isEmpty {
            predicateParts.append(NSPredicate(
                format: "title CONTAINS[cd] %@ OR ANY messages.content CONTAINS[cd] %@",
                query, query
            ))
        }
        
        // Combine predicates
        if predicateParts.count > 1 {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicateParts)
        } else {
            request.predicate = predicateParts.first
        }
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error searching conversations: \(error)")
            return []
        }
    }
    
    /// Update conversation title
    func updateConversationTitle(_ conversation: Conversation, title: String) {
        conversation.title = title
        conversation.updatedAt = Date()
        saveContext()
    }
    
    /// Toggle bookmark status
    func toggleBookmark(_ conversation: Conversation) {
        conversation.isBookmarked.toggle()
        saveContext()
    }
    
    /// Delete a conversation
    func deleteConversation(_ conversation: Conversation) {
        let context = container.viewContext
        context.delete(conversation)
        saveContext()
    }
    
    /// Delete all conversations
    func deleteAllConversations() {
        let context = container.viewContext
        let request: NSFetchRequest<NSFetchRequestResult> = Conversation.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        do {
            try context.execute(deleteRequest)
            saveContext()
        } catch {
            print("Error deleting all conversations: \(error)")
        }
    }
    
    /// Cleanup empty conversations (conversations with no messages)
    func cleanupEmptyConversations() {
        let context = container.viewContext
        let request: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        request.predicate = NSPredicate(format: "messages.@count == 0")
        
        do {
            let emptyConversations = try context.fetch(request)
            for conversation in emptyConversations {
                context.delete(conversation)
            }
            if !emptyConversations.isEmpty {
                saveContext()
                print("🧹 Cleaned up \(emptyConversations.count) empty conversation(s)")
            }
        } catch {
            print("Error cleaning up empty conversations: \(error)")
        }
    }
    
    /// Check if a conversation is empty (has no messages)
    func isConversationEmpty(_ conversation: Conversation) -> Bool {
        guard let messages = conversation.messages as? Set<Message> else {
            return true
        }
        return messages.isEmpty
    }
    
    // MARK: - Message CRUD Operations
    
    /// Add a message to a conversation
    func addMessage(to conversation: Conversation, content: String, role: String, sources: [Source] = [], followUpSuggestions: [String] = []) -> Message {
        let context = container.viewContext
        let message = Message(context: context)
        message.id = UUID()
        message.content = content
        message.role = role
        message.timestamp = Date()
        message.conversation = conversation
        message.sourcesJSON = sources.toJSONString()
        message.followUpSuggestionsJSON = followUpSuggestions.toJSONString()
        
        // Update conversation timestamp
        conversation.updatedAt = Date()
        
        // Update conversation title from first user message if it's still default
        if conversation.title == "New Chat" && role == "user" {
            let truncatedTitle = String(content.prefix(50))
            conversation.title = truncatedTitle + (content.count > 50 ? "..." : "")
        }
        
        // Save context - conversation will be persisted now that it has at least one message
        saveContext()
        return message
    }
    
    /// Fetch messages for a conversation
    func fetchMessages(for conversation: Conversation) -> [Message] {
        let context = container.viewContext
        let request: NSFetchRequest<Message> = Message.fetchRequest()
        request.predicate = NSPredicate(format: "conversation == %@", conversation)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Message.timestamp, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching messages: \(error)")
            return []
        }
    }
    
    // MARK: - Core Data Saving
    
    func saveContext() {
        let context = container.viewContext
        
        // Safety check: only save if context has changes and is valid
        guard context.hasChanges else { return }
        
        // Check if context is in a valid state
        guard context.persistentStoreCoordinator != nil else {
            print("⚠️ Cannot save: persistent store coordinator is nil (stores may not be loaded)")
            return
        }
        
        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            print("❌ Error saving context: \(nsError.localizedDescription)")
            print("   Error domain: \(nsError.domain), code: \(nsError.code)")
            print("   User info: \(nsError.userInfo)")
            // Don't crash - just log the error
        }
    }
}
