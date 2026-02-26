//
//  SourceListView.swift
//  lawgpt
//
//  Created by Bash33r on 01/12/25.
//

import SwiftUI
import SafariServices

struct SourceListView: View {
    let sources: [Source]
    let onSourceTap: (Source) -> Void
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("References")
                .font(DesignSystem.heading3Font())
                .padding(.bottom, 4)
            
            if let firstSource = sources.first {
                SourceCard(source: firstSource, index: 1, onTap: { onSourceTap(firstSource) })
                
                if sources.count > 1 {
                    Button(action: {
                        HapticManager.shared.selection()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            Text(isExpanded ? "Show less" : "Show \(sources.count - 1) more")
                                .font(DesignSystem.bodyFont())
                        }
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                    }
                }
                
                if isExpanded {
                    ForEach(Array(sources.dropFirst().enumerated()), id: \.element.id) { idx, source in
                        SourceCard(source: source, index: idx + 2, onTap: { onSourceTap(source) })
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
        .padding(.top, 16)
    }
}

struct SourceCard: View {
    let source: Source
    let index: Int
    let onTap: () -> Void
    @State private var showSafari = false
    
    var body: some View {
        Button(action: {
            HapticManager.shared.selection()
            if URL(string: source.url) != nil {
                showSafari = true
            } else {
                // Fallback to original onTap if URL is invalid
                onTap()
            }
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Text("\(index)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                
                if let favicon = source.faviconURL {
                    AsyncImage(url: favicon) { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "globe")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: "doc.text")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(source.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(source.domain)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showSafari) {
            if let url = URL(string: source.url) {
                SafariView(url: url)
            }
        }
    }
}
