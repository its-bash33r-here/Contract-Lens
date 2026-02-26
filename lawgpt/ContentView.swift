//
//  ContentView.swift
//  lawgpt
//
//  Created by Bash33r on 01/12/25.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var showHistory = false
    @State private var selectedConversation: Conversation?
    @State private var navigateToChat = false
    @State private var showSearch = false
    @StateObject private var chatViewModel = ChatViewModel()
    @State private var historyDragOffset: CGFloat = 0
    @State private var showScanner = false
    
    // Platform detection
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        Group {
            if isIPad {
                tabletHome
            } else {
                phoneHome
            }
        }
    }
    
    // MARK: - Phone layout
    private var phoneHome: some View {
        ZStack(alignment: .bottom) {
            homeBackground
            
            VStack {
                historyAndSettingsBar
                Spacer()
            }
            
            // Left-edge drag to open history (phone)
            HStack(spacing: 0) {
                edgeHistoryOpener
                Spacer()
            }
            .ignoresSafeArea()
            
            homeContent(iconSize: 72, titleSize: 42, verticalPadding: 100)
            floatingInputBar(horizontalPadding: 24, bottomPadding: 40, widthLimit: nil)
        }
        .fullScreenCover(isPresented: $navigateToChat) {
            ActiveChatView(viewModel: chatViewModel)
        }
        .fullScreenCover(isPresented: $showScanner) {
            ContractScannerView()
        }
        .sheet(isPresented: $showHistory) {
            HistoryView(
                isPresented: $showHistory,
                onSelectConversation: { conversation in
                    // Opening history from the home screen is available to all users
                    selectedConversation = conversation
                    chatViewModel.loadConversation(conversation)
                    navigateToChat = true
                    showHistory = false
                }
            )
        }
    }
    
    // MARK: - Tablet layout (iPad)
    private var tabletHome: some View {
        ZStack(alignment: .bottom) {
            homeBackground
            
            // Wider content with centered column and optional history shortcut
            VStack(spacing: 0) {
                HStack {
                    historyButton
                    Spacer()
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 24))
                            .foregroundColor(.primary)
                    }
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            HapticManager.shared.lightImpact()
                        }
                    )
                }
                .padding(.horizontal, 32)
                .padding(.top, 24)
                
                Spacer()
                
                homeContent(iconSize: 88, titleSize: 48, verticalPadding: 120)
                    .frame(maxWidth: 520)
                    .padding(.horizontal, 32)
                
                Spacer()
            }
            
            // Left-edge drag to open history
            HStack(spacing: 0) {
                edgeHistoryOpener
                Spacer()
            }
            .ignoresSafeArea()
            
            floatingInputBar(horizontalPadding: 80, bottomPadding: 60, widthLimit: 560)
            
            // Slide-over history panel (left docked)
            if showHistory {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut) { showHistory = false; historyDragOffset = 0 }
                    }
                
                HStack(spacing: 0) {
                    historyPanel
                        .frame(width: 420)
                        .offset(x: historyDragOffset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    historyDragOffset = min(0, value.translation.width)
                                }
                                .onEnded { value in
                                    if value.translation.width < -80 {
                                        withAnimation(.easeOut) {
                                            showHistory = false
                                            historyDragOffset = 0
                                        }
                                    } else {
                                        withAnimation(.easeOut) {
                                            historyDragOffset = 0
                                        }
                                    }
                                }
                        )
                        .transition(.move(edge: .leading))
                    
                    Spacer()
                }
                .animation(.easeOut, value: showHistory)
            }
        }
        .fullScreenCover(isPresented: $navigateToChat) {
            ActiveChatView(viewModel: chatViewModel)
        }
        .fullScreenCover(isPresented: $showScanner) {
            ContractScannerView()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            // Save draft input when app goes to background
            chatViewModel.saveDraftInput()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
            // Save draft input when app is about to terminate
            chatViewModel.saveDraftInput()
        }
    }
    
    // MARK: - Shared subviews
    
    private var homeBackground: some View {
        ZStack {
            Color(.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            LinearGradient(
                colors: [DesignSystem.highlightColor.opacity(0.1), Color(.systemBackground)],
                startPoint: .topLeading,
                endPoint: .center
            )
            .edgesIgnoringSafeArea(.all)
        }
    }
    
    private func homeContent(iconSize: CGFloat, titleSize: CGFloat, verticalPadding: CGFloat) -> some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 24) {
                AppLogoGradientView(size: iconSize * 2.4)
                
                Text("ClauseGuard")
                    .font(.system(size: titleSize, weight: .bold, design: .serif))
                    .foregroundColor(.primary)
                
                Text("Your AI Contract Lawyer\nSpot red flags. Negotiate better.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .lineSpacing(6)
            }
            .padding(.bottom, verticalPadding)
            Spacer()
        }
    }
    
    private var historyAndSettingsBar: some View {
        HStack {
            historyButton
            Spacer()
            NavigationLink(destination: SettingsView()) {
                Image(systemName: "gearshape")
                    .font(.system(size: 22))
                    .foregroundColor(.primary)
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    HapticManager.shared.lightImpact()
                }
            )
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
    
    private var historyButton: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            withAnimation { showHistory = true }
        }) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 22))
                .foregroundColor(.primary)
        }
        .accessibilityLabel("History")
    }
    
    private func floatingInputBar(horizontalPadding: CGFloat, bottomPadding: CGFloat, widthLimit: CGFloat?) -> some View {
        VStack(spacing: 12) {
            // Primary CTA: Scan Contract
            Button(action: {
                HapticManager.shared.mediumImpact()
                showScanner = true
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Scan a Contract")
                        .font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.vertical, 16)
                .padding(.horizontal, 22)
                .frame(maxWidth: widthLimit)
                .background(
                    LinearGradient(
                        colors: [DesignSystem.accentColor, DesignSystem.legalBlueDark],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .cornerRadius(32)
                .shadow(
                    color: DesignSystem.accentColor.opacity(0.35),
                    radius: 16, x: 0, y: 6
                )
            }
            .padding(.horizontal, horizontalPadding)

            // Secondary: Ask a question (existing chat)
            Button(action: {
                HapticManager.shared.lightImpact()
                chatViewModel.startNewConversation()
                navigateToChat = true
            }) {
                HStack {
                    Text("Ask a legal question...")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "mic.fill")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 24)
                .frame(maxWidth: widthLimit)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(32)
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(Color(.separator).opacity(0.6), lineWidth: 0.5)
                )
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12),
                    radius: 20,
                    x: 0,
                    y: 8
                )
            }
            .padding(.horizontal, horizontalPadding)
        }
        .padding(.bottom, bottomPadding)
    }

    private var historyPanel: some View {
        HistoryView(
            isPresented: $showHistory,
            onSelectConversation: { conversation in
                selectedConversation = conversation
                chatViewModel.loadConversation(conversation)
                navigateToChat = true
                showHistory = false
                historyDragOffset = 0
            }
        )
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.18), radius: 16, x: 0, y: 8)
        .padding(.leading, 12)
        .padding(.vertical, 20)
    }
    
    private var edgeHistoryOpener: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 24)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        // Start near left edge and drag right to open
                        if !showHistory,
                           value.startLocation.x < 30,
                           value.translation.width > 40 {
                            withAnimation(.easeOut) {
                                showHistory = true
                            }
                        }
                    }
            )
    }
}

#Preview {
    ContentView()
}
