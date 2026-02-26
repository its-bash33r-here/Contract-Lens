//
//  ActiveChatView.swift
//  lawgpt
//
//  Created by Bash33r on 03/12/25.
//

import SwiftUI
import UIKit

struct ActiveChatView: View {
    @StateObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    @State private var focusedMessageIndex: Int? = nil
    @State private var lastScrollOffset: CGFloat = 0
    @State private var scrollDirection: ActiveScrollDirection = .down
    
    // State to track if we are in the initial input phase
    @State private var isInitialInput: Bool = true
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Custom Nav Bar (close button and bookmark)
                HStack {
                    Button(action: {
                        HapticManager.shared.selection()
                        // Save input text before dismissing
                        viewModel.saveDraftInput()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    Spacer()
                    
                    // Bookmark button (only show if conversation exists)
                    if viewModel.conversation != nil {
                        BookmarkButton(
                            isBookmarked: viewModel.isBookmarked,
                            onToggle: {
                                // Haptic feedback: success when bookmarking, selection when unbookmarking
                                let wasBookmarked = viewModel.isBookmarked
                                viewModel.toggleBookmark()
                                
                                // Provide haptic feedback based on new state
                                if wasBookmarked {
                                    // Was bookmarked, now unbookmarked
                                    HapticManager.shared.selection()
                                } else {
                                    // Was not bookmarked, now bookmarked
                                    HapticManager.shared.success()
                                }
                            }
                        )
                    }
                }
                .padding()
                
                if isInitialInput {
                    // Phase 1: Initial Input
                    initialInputView
                } else {
                    // Phase 2: Chat Interface (Loading -> Result)
                    chatResultView
                }
            }
        }
        .onAppear {
            viewModel.restoreDraftInput()

            if viewModel.messages.isEmpty {
                isInitialInput = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isFocused = true
                }
            } else {
                isInitialInput = false
            }
        }
    }
    
    // MARK: - Phase 1: Initial Input View
    
    var initialInputView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top TextField
            TextField("Ask a legal question...", text: $viewModel.inputText, axis: .vertical)
                .font(DesignSystem.heading2Font())
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .focused($isFocused)
                .disabled(viewModel.isLoading)
                .submitLabel(.send)
                .onSubmit {
                    submitMessage()
                }
            
            Spacer()
            
            // Bottom Mode Selector
            VStack(spacing: 0) {
                Divider()
                HStack {
                    Menu {
                        ForEach(ChatMode.allCases) { mode in
                            Button(action: {
                                HapticManager.shared.selection()
                                viewModel.selectedMode = mode
                            }) {
                                Label(mode.rawValue, systemImage: mode.icon)
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: viewModel.selectedMode.icon)
                            Text(viewModel.selectedMode.rawValue)
                            Image(systemName: "chevron.up")
                                .font(.caption)
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                    }
                    
                    Spacer()
                    
                    // Send Button (visible if text is not empty)
                    if !viewModel.inputText.isEmpty {
                        Button(action: {
                            HapticManager.shared.selection()
                            submitMessage()
                        }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(viewModel.isLoading ? Color.gray : DesignSystem.highlightColor) // Grey when loading, Legal blue when enabled
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
                .padding(16)
            }
        }
    }
    
    // MARK: - Phase 2: Result View
    
    var chatResultView: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ZStack(alignment: .bottomTrailing) {
                    chatScrollView(proxy: proxy)
                    if shouldShowScrollControls {
                        scrollControls(proxy: proxy)
                    }
                }
            }
            
            // Bottom "Follow up" bar
            chatBottomBar
        }
    }
    
    @ViewBuilder
    private func chatScrollView(proxy: ScrollViewProxy) -> some View {
                    ScrollView {
                        VStack(spacing: 0) {
                messagesList
                quotaErrorView
                followUpSuggestionsView
                loadingView
            }
            .padding(.bottom, 80)
            .background(scrollOffsetBackground)
        }
        .coordinateSpace(name: "activeChatScroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            let delta = value - lastScrollOffset
            if abs(delta) > 2 {
                scrollDirection = delta < 0 ? .down : .up
            }
            lastScrollOffset = value
        }
        .onChange(of: viewModel.messages.count) { _ in
            normalizeFocusedIndex()
            if shouldAutoScrollToBottom {
                scrollToBottom(proxy: proxy)
            }
        }
        .onChange(of: viewModel.isLoading) { loading in
            if loading && shouldAutoScrollToBottom {
                scrollToBottom(proxy: proxy)
            }
        }
        .onChange(of: viewModel.isAnimatingResponse) { animating in
            if animating && shouldAutoScrollToBottom {
                // Scroll to animated response
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        proxy.scrollTo("animated-response", anchor: .bottom)
                    }
                }
            }
        }
        .onChange(of: viewModel.animatedResponseText) { _ in
            // Auto-scroll as text animates
            if viewModel.isAnimatingResponse && shouldAutoScrollToBottom {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("animated-response", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var messagesList: some View {
                            ForEach(viewModel.messages, id: \.id) { message in
                                MessageBubbleView(
                                    message: message,
                                    onSourceTap: { source in
                                        viewModel.showSource(source)
                                    },
                                    onCopy: {
                                        HapticManager.shared.selection()
                                        viewModel.copyMessage(message)
                                    },
                                    onShare: {
                                        HapticManager.shared.selection()
                                        shareMessage(message)
                                    },
                                    onEdit: { msg, newText in
                                        handleUserEdit(message: msg, newText: newText)
                                    }
                                )
                                .id(message.id)
        }
                            
                            // Show animated response while animating
                            if viewModel.isAnimatingResponse && !viewModel.animatedResponseText.isEmpty {
                                AnimatedResponseView(text: viewModel.animatedResponseText)
                                    .id("animated-response")
                            }
                            }
                            
    @ViewBuilder
    private var quotaErrorView: some View {
                            if viewModel.showQuotaExhaustedRetry && !viewModel.isLoading {
                                VStack(spacing: 12) {
                                    if let errorMsg = viewModel.errorMessage {
                                        Text(errorMsg)
                                            .font(DesignSystem.bodyFont())
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 24)
                                            .padding(.top, 16)
                                    }
                                    
                                    Button(action: {
                                        HapticManager.shared.selection()
                                        Task {
                                            await viewModel.retryWithFallbackModel()
                                        }
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "arrow.clockwise")
                                            Text("Retry")
                                                .fontWeight(.semibold)
                                        }
                                        .font(DesignSystem.bodyFont())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                        .background(DesignSystem.highlightColor)
                                        .cornerRadius(12)
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.top, 8)
            }
                                }
                            }
                            
    @ViewBuilder
    private var followUpSuggestionsView: some View {
                            if !viewModel.isLoading {
                                let followUps = Array(viewModel.followUpSuggestions.prefix(3))
                                if !followUps.isEmpty {
                                    followUpCard(suggestions: followUps)
                                        .padding(.horizontal, 20)
                                        .padding(.top, 12)
            }
                                }
                            }
                            
    @ViewBuilder
    private var loadingView: some View {
                            if viewModel.isLoading && !viewModel.isAnimatingResponse {
                                SkeletonLoadingView(statusText: viewModel.loadingStatus)
                                    .id("loading")
                            }
                        }
    
    private var scrollOffsetBackground: some View {
                            GeometryReader { geo in
                                Color.clear
                                    .preference(key: ScrollOffsetPreferenceKey.self, value: geo.frame(in: .named("activeChatScroll")).minY)
                            }
    }
    
    @ViewBuilder
    private func scrollControls(proxy: ScrollViewProxy) -> some View {
                        ActiveChatScrollControls(
                            direction: scrollDirection,
                            canScrollUp: canScrollUp,
                            canScrollDown: canScrollDown,
                            onScrollUp: {
                                handleScrollUp(proxy: proxy)
                            },
                            onScrollDown: {
                                handleScrollDown(proxy: proxy)
                            }
                        )
                        .padding(.trailing, 16)
        .padding(.bottom, 32)
            }
            
    private var chatBottomBar: some View {
            VStack(spacing: 0) {
                Divider()
                HStack {
                    TextField("Ask follow up...", text: $viewModel.inputText)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                        .disabled(viewModel.isLoading)
                        .submitLabel(.send)
                        .onSubmit {
                            Task { await viewModel.sendMessage() }
                        }
                    
                    if !viewModel.inputText.isEmpty {
                        Button(action: {
                            HapticManager.shared.selection()
                            Task { await viewModel.sendMessage() }
                        }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                            .foregroundStyle(viewModel.isLoading ? Color.gray : DesignSystem.highlightColor)
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Scroll Navigation Logic
    
    private var shouldShowScrollControls: Bool {
        guard viewModel.messages.count > 0 else { return false }
        let hasScrollUp = canScrollUp
        let hasScrollDown = canScrollDown
        switch scrollDirection {
        case .up: return hasScrollUp
        case .down: return hasScrollDown
        case .none: return hasScrollUp || hasScrollDown
        }
    }
    
    private var canScrollUp: Bool {
        viewModel.messages.count > 1
    }
    
    private var canScrollDown: Bool {
        viewModel.messages.count > 1
    }
    
    private var isBrowsingHistory: Bool {
        guard !viewModel.messages.isEmpty, let focused = focusedMessageIndex else { return false }
        return focused < viewModel.messages.count - 1
    }
    
    private var shouldAutoScrollToBottom: Bool {
        !isBrowsingHistory
    }
    
    private func normalizeFocusedIndex() {
        guard let focused = focusedMessageIndex else { return }
        if viewModel.messages.isEmpty {
            focusedMessageIndex = nil
        } else if focused >= viewModel.messages.count {
            focusedMessageIndex = viewModel.messages.count - 1
        }
    }
    
    private func handleScrollUp(proxy: ScrollViewProxy) {
        guard canScrollUp else { return }
        
        let startIndex = focusedMessageIndex ?? (viewModel.messages.count - 1)
        let targetIndex = max(0, startIndex - 1)
        
        scrollToMessage(at: targetIndex, proxy: proxy)
        focusedMessageIndex = targetIndex
        HapticManager.shared.selection()
    }
    
    private func handleScrollDown(proxy: ScrollViewProxy) {
        guard !viewModel.messages.isEmpty else { return }
        
        let lastIndex = viewModel.messages.count - 1
        
        // If focusedMessageIndex is nil, we might have manually scrolled up
        // In that case, try scrolling to the last message to reach the bottom
        if focusedMessageIndex == nil {
            scrollToMessage(at: lastIndex, proxy: proxy, useBottomAnchor: true)
            focusedMessageIndex = lastIndex
            HapticManager.shared.selection()
            return
        }
        
        // Otherwise, scroll to next message
        guard canScrollDown else { return }
        let startIndex = focusedMessageIndex!
        let targetIndex = min(lastIndex, startIndex + 1)
        
        // Use bottom anchor when scrolling to the last message to ensure we reach absolute bottom
        let useBottomAnchor = targetIndex == lastIndex
        scrollToMessage(at: targetIndex, proxy: proxy, useBottomAnchor: useBottomAnchor)
        focusedMessageIndex = targetIndex
        HapticManager.shared.selection()
    }
    
    private func scrollToMessage(at index: Int, proxy: ScrollViewProxy, useBottomAnchor: Bool = false) {
        guard viewModel.messages.indices.contains(index) else { return }
        let message = viewModel.messages[index]
        withAnimation(.easeInOut(duration: 0.25)) {
            proxy.scrollTo(message.id, anchor: useBottomAnchor ? .bottom : .top)
        }
    }
    
    private func submitMessage() {
        guard !viewModel.isLoading else { return }
        isInitialInput = false
        Task { await viewModel.sendMessage() }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation {
            if viewModel.isAnimatingResponse {
                proxy.scrollTo("animated-response", anchor: .bottom)
            } else if viewModel.isLoading {
                proxy.scrollTo("loading", anchor: .bottom)
            } else if let last = viewModel.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
    
    private func shareMessage(_ message: Message) {
        let text = viewModel.shareMessage(message)
        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            // Present from the top-most view controller
            var topVC = rootVC
            while let presentedVC = topVC.presentedViewController {
                topVC = presentedVC
            }
            topVC.present(activityVC, animated: true)
        }
    }
    
    // MARK: - Follow-Up Card
    @ViewBuilder
    private func followUpCard(suggestions: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 18, weight: .semibold))
                Text("Follow-Up Questions")
                    .font(DesignSystem.heading3Font())
            }
            .foregroundColor(.primary)
            
            VStack(spacing: 0) {
                ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                    Button {
                        HapticManager.shared.selection()
                        handleFollowUpTap(suggestion)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Text(suggestion)
                                .font(DesignSystem.bodyFont())
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    
                    if index < suggestions.count - 1 {
                        Divider()
                            .padding(.leading, 4)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
        )
    }
    
    private func handleFollowUpTap(_ suggestion: String) {
        viewModel.inputText = suggestion
        isInitialInput = false
        Task { await viewModel.sendMessage() }
    }
    
    // Handle user message edits: update content, save, and trigger a new response
    private func handleUserEdit(message: Message, newText: String) {
        // Update message content in Core Data
        message.content = newText
        message.timestamp = Date()
        message.conversation?.updatedAt = Date()
        PersistenceController.shared.saveContext()
        
        // Trigger a new response using the edited text
        viewModel.inputText = newText
        isInitialInput = false
        Task {
            await viewModel.sendMessage()
        }
    }
}

// MARK: - Shared UI Helpers

/// Small circular button style used for scroll controls
struct ScrollCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.primary)
            .frame(width: 34, height: 34)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

/// Bookmark toggle button with bounce animation
struct BookmarkButton: View {
    let isBookmarked: Bool
    let onToggle: () -> Void
    
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Button(action: {
            // Animate scale on tap
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                scale = 0.8
            }
            
            onToggle()
            
            // Animate back with bounce
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    scale = 1.0
                }
            }
        }) {
            Image(systemName: isBookmarked ? "star.fill" : "star")
                .foregroundColor(isBookmarked ? .yellow : .primary)
                .scaleEffect(scale)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isBookmarked)
        }
    }
}

// MARK: - Scroll Controls
struct ActiveChatScrollControls: View {
    let direction: ActiveScrollDirection
    let canScrollUp: Bool
    let canScrollDown: Bool
    let onScrollUp: () -> Void
    let onScrollDown: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            if direction == .up {
                Button(action: onScrollUp) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(ScrollCircleButtonStyle())
                .disabled(!canScrollUp)
                .opacity(canScrollUp ? 1.0 : 0.35)
                .accessibilityLabel("Scroll to previous message")
            }
            
            if direction == .down {
                Button(action: onScrollDown) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(ScrollCircleButtonStyle())
                .disabled(!canScrollDown)
                .opacity(canScrollDown ? 1.0 : 0.35)
                .accessibilityLabel("Scroll to next message")
            }
        }
    }
}

enum ActiveScrollDirection {
    case up, down, none
}

// MARK: - Animated Response View
struct AnimatedResponseView: View {
    let text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Article-style animated content
            ArticleTextView(
                text: text,
                sources: [], // No sources during animation
                onSourceTap: { _ in }
            )
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .messageFadeIn(delay: 0.1)
    }
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
