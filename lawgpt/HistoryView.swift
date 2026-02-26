//
//  HistoryView.swift
//  lawgpt
//
//  Created by Bash33r on 01/12/25.
//

import SwiftUI

struct HistoryView: View {
    @Binding var isPresented: Bool
    var onSelectConversation: ((Conversation) -> Void)?
    
    @StateObject private var viewModel = HistoryViewModel()
    @State private var showUndoBanner = false
    @State private var undoConversationId: UUID?
    @State private var undoTitle: String = ""
    @State private var undoHideWorkItem: DispatchWorkItem?
    
    var body: some View {
        ZStack {
            // Background
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            historyContent
        }
        .overlay(alignment: .bottom) {
            undoBannerOverlay
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    let horizontalDistance = value.translation.width
                    if horizontalDistance < -100 {
                        withAnimation {
                            isPresented = false
                        }
                    }
                }
        )
        .onAppear {
            viewModel.loadConversations()
        }
    }
    
    private var historyContent: some View {
        VStack(spacing: 0) {
            historyHeader
            historySearchBar
            historyFilterToggle
            historyConversationList
        }
    }
    
    @ViewBuilder
    private var historyHeader: some View {
                HStack {
                    Text("History")
                        .font(DesignSystem.heading1Font())
                        .accessibilityAddTraits(.isHeader)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("Close history")
                    .frame(minWidth: 44, minHeight: 44) // Minimum touch target
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)
    }
                
    @ViewBuilder
    private var historySearchBar: some View {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search conversations", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .onChange(of: viewModel.searchText) { _ in
                            viewModel.search()
                        }
                    
                    if !viewModel.searchText.isEmpty {
                        Button(action: {
                            viewModel.searchText = ""
                            viewModel.loadConversations()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
    }
                
    @ViewBuilder
    private var historyFilterToggle: some View {
                HStack {
                    Button(action: {
                        HapticManager.shared.selection()
                        viewModel.showBookmarkedOnly = false
                    }) {
                        Text("All")
                            .font(DesignSystem.secondaryBodyFont())
                            .fontWeight(viewModel.showBookmarkedOnly ? .regular : .semibold)
                            .foregroundColor(viewModel.showBookmarkedOnly ? .secondary : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .frame(minHeight: 44) // Minimum touch target
                            .background(viewModel.showBookmarkedOnly ? Color.clear : Color(.systemGray5))
                            .cornerRadius(20)
                    }
                    .accessibilityLabel("Show all conversations")
                    
                    Button(action: {
                        HapticManager.shared.selection()
                        viewModel.showBookmarkedOnly = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(DesignSystem.captionFont())
                            Text("Bookmarked")
                                .font(DesignSystem.secondaryBodyFont())
                        }
                        .fontWeight(viewModel.showBookmarkedOnly ? .semibold : .regular)
                        .foregroundColor(viewModel.showBookmarkedOnly ? .primary : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(minHeight: 44) // Minimum touch target
                        .background(viewModel.showBookmarkedOnly ? Color(.systemGray5) : Color.clear)
                        .cornerRadius(20)
                    }
                    .accessibilityLabel("Show bookmarked conversations only")
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
    }
                
    @ViewBuilder
    private var historyConversationList: some View {
                if viewModel.filteredConversations.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        
                        Image(systemName: viewModel.showBookmarkedOnly ? "star" : "bubble.left.and.bubble.right")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary.opacity(0.5))
                        
                        Text(viewModel.showBookmarkedOnly ? "No bookmarked conversations" : "No conversations yet")
                            .font(DesignSystem.heading3Font())
                            .foregroundColor(.secondary)
                        
                        Text(viewModel.showBookmarkedOnly ? "Star conversations to see them here" : "Start a new conversation to see it here")
                            .font(DesignSystem.secondaryBodyFont())
                            .foregroundColor(.secondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 40)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.filteredConversations, id: \.id) { conversation in
                                ConversationRow(
                                    conversation: conversation,
                                    previewText: viewModel.previewText(for: conversation),
                                    formattedDate: viewModel.formattedDate(conversation.updatedAt),
                                    onTap: {
                                        onSelectConversation?(conversation)
                                    },
                                    onBookmark: {
                                        viewModel.toggleBookmark(conversation)
                                    },
                                    onDelete: {
                                        guard let convoId = conversation.id else { return }
                                        HapticManager.shared.warning()
                                        undoHideWorkItem?.cancel()
                                        undoConversationId = convoId
                                        undoTitle = conversation.title ?? "Conversation"
                                        showUndoBanner = true
                                        viewModel.scheduleDelete(conversation)
                                        
                                        let workItem = DispatchWorkItem {
                                            Task { @MainActor in
                                                showUndoBanner = false
                                                undoConversationId = nil
                                                undoHideWorkItem = nil
                                            }
                                        }
                                        undoHideWorkItem = workItem
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: workItem)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
    
    private var undoBannerOverlay: some View {
        Group {
            if showUndoBanner {
                HStack(spacing: 12) {
                    Image(systemName: "trash")
                        .foregroundColor(.secondary)
                    Text("Deleted \"\(undoTitle)\"")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Spacer()
                    Button("Undo") {
                        HapticManager.shared.selection()
                        undoHideWorkItem?.cancel()
                        if let convoId = undoConversationId {
                            viewModel.cancelScheduledDelete(conversationId: convoId)
                        }
                        showUndoBanner = false
                        undoConversationId = nil
                        undoHideWorkItem = nil
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial)
                .cornerRadius(16)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut, value: showUndoBanner)
            }
        }
    }
}

// MARK: - Conversation Row
struct ConversationRow: View {
    let conversation: Conversation
    let previewText: String
    let formattedDate: String
    let onTap: () -> Void
    let onBookmark: () -> Void
    let onDelete: () -> Void
    @State private var showMenu = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Bookmark indicator with animation
                Group {
                    if conversation.isBookmarked {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 16)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: conversation.isBookmarked)
                
                VStack(alignment: .leading, spacing: 6) {
                    // Title
                    Text(conversation.title ?? "New Chat")
                        .font(DesignSystem.heading3Font())
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    // Preview text
                    Text(previewText)
                        .font(DesignSystem.secondaryBodyFont())
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Date + menu
                VStack(alignment: .trailing, spacing: 6) {
                    Text(formattedDate)
                        .font(DesignSystem.captionFont())
                        .foregroundColor(.secondary)
                    
                    Menu {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .rotationEffect(.degrees(90))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                    }
                    .menuStyle(.borderlessButton)
                    .contentShape(Rectangle())
                }
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44) // Minimum touch target
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Conversation: \(conversation.title ?? "New Chat")")
        .accessibilityHint("Double tap to open conversation")
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: {
                HapticManager.shared.warning()
                onDelete()
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: {
                HapticManager.shared.selection()
                onBookmark()
            }) {
                Label(
                    conversation.isBookmarked ? "Unbookmark" : "Bookmark",
                    systemImage: conversation.isBookmarked ? "star.slash" : "star.fill"
                )
            }
            .tint(.yellow)
        }
        
        Divider()
            .padding(.leading, 28)
    }
}

#Preview {
    HistoryView(
        isPresented: .constant(true),
        onSelectConversation: { _ in }
    )
}
