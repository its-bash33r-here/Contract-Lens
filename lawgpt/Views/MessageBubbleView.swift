//
//  MessageBubbleView.swift
//  lawgpt
//
//  Created by Bash33r on 01/12/25.
//

import SwiftUI
import CoreData

/// View for displaying individual chat messages with citations
struct MessageBubbleView: View {
    let message: Message
    let onSourceTap: (Source) -> Void
    let onCopy: () -> Void
    let onShare: () -> Void
    let onEdit: ((Message, String) -> Void)?
    
    @State private var showActions = false
    @State private var showExportOptions = false
    @State private var isEditing = false
    @State private var editText: String = ""
    
    private var isUser: Bool {
        message.role == "user"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isUser {
                // User message - Right aligned, large text
                HStack {
                    Spacer()
                    Text(message.content ?? "")
                        .font(DesignSystem.heading3Font())
                        .foregroundColor(.primary) // Darker text for user question
                        .multilineTextAlignment(.trailing)
                        .textSelection(.enabled)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 18)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color(.separator).opacity(0.25), lineWidth: 0.5)
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                }
                .messageFadeIn()
                .onLongPressGesture {
                    guard onEdit != nil else { return }
                    editText = message.content ?? ""
                    isEditing = true
                    HapticManager.shared.selection()
                }
                .accessibilityLabel("Question: \(message.content ?? "")")
                .accessibilityAddTraits(.isHeader)
                .sheet(isPresented: $isEditing) {
                    NavigationStack {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Edit your question")
                                .font(DesignSystem.heading2Font())
                            
                            TextEditor(text: $editText)
                                .padding(12)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                                .frame(minHeight: 160)
                            
                            Spacer()
                        }
                        .padding()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    isEditing = false
                                }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Save") {
                                    isEditing = false
                                    let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !trimmed.isEmpty else { return }
                                    HapticManager.shared.lightImpact()
                                    onEdit?(message, trimmed)
                                }
                                .bold()
                            }
                        }
                    }
                    .presentationDetents([.medium, .large])
                }
            } else {
                // Assistant message - full-width article style
                VStack(alignment: .leading, spacing: 16) {
                    // Article content with citations - native text selection enabled
                    ArticleTextView(
                        text: message.content ?? "",
                        sources: message.sources,
                        onSourceTap: onSourceTap
                    )
                    
                    // Source cards for assistant messages
                    if !message.sources.isEmpty {
                        SourceListView(
                            sources: message.sources,
                            onSourceTap: onSourceTap
                        )
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
                .messageFadeIn(delay: 0.1)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Legal response with \(message.sources.count) source\(message.sources.count == 1 ? "" : "s")")
                .sheet(isPresented: $showExportOptions) {
                    ExportOptionsView(
                        message: message,
                        conversation: nil,
                        messages: nil
                    )
                }
            }
        }
    }
}

// MARK: - Article Text View
/// Displays article-style text with interactive citations and rich formatting
struct ArticleTextView: View {
    let text: String
    let sources: [Source]
    let onSourceTap: (Source) -> Void
    
    var body: some View {
        let paragraphs = parseIntoParagraphs(text)
        let keyPoints = extractKeyPoints(from: text)
        let hasHeadings = paragraphs.contains { isHeading($0) }
        
        print("📄 ArticleTextView: body called")
        print("   📊 Total paragraphs: \(paragraphs.count)")
        print("   ✨ Key points extracted: \(keyPoints.count)")
        print("   📑 Has headings: \(hasHeadings)")
        if !keyPoints.isEmpty {
            print("   📋 Key points: \(keyPoints)")
        }
        if hasHeadings {
            let headingCount = paragraphs.filter { isHeading($0) }.count
            print("   📌 Heading count: \(headingCount)")
        }
        
        return VStack(alignment: .leading, spacing: 0) {
            // Summary box at the top if we have key points
            if !keyPoints.isEmpty {
                SummaryBox(keyPoints: keyPoints)
                    .padding(.bottom, DesignSystem.paragraphSpacing)
                    .onAppear {
                        print("✅ SummaryBox displayed with \(keyPoints.count) key points")
                    }
            }
            
            // Main content
            VStack(alignment: .leading, spacing: DesignSystem.paragraphSpacing) {
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                    let isHeadingParagraph = isHeading(paragraph)
                    
                    // Add section divider before headings (except the first one)
                    if isHeadingParagraph && index > 0 && hasHeadings {
                        SectionDivider()
                            .onAppear {
                                print("➖ SectionDivider added before heading at index \(index)")
                            }
                    }
                    
                    ParagraphView(
                        paragraph: paragraph,
                        sources: sources,
                        onSourceTap: onSourceTap,
                        isFirstParagraph: index == 0
                    )
                    .onAppear {
                        if isHeadingParagraph {
                            let level = getHeadingLevel(paragraph)
                            print("📌 Heading level \(level) rendered at index \(index)")
                        }
                    }
                }
            }
        }
        .textSelection(.enabled)
    }
    
    private func getHeadingLevel(_ text: String) -> Int {
        if text.hasPrefix("# ") {
            return 1
        } else if text.hasPrefix("## ") {
            return 2
        } else if text.hasPrefix("### ") {
            return 3
        }
        return 2 // Default
    }
    
    private func isHeading(_ text: String) -> Bool {
        text.hasPrefix("# ") || text.hasPrefix("## ") || text.hasPrefix("### ")
    }
    
    private func parseIntoParagraphs(_ text: String) -> [String] {
        let splitParagraphs = text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        if splitParagraphs.count <= 1 {
            return text.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        
        return splitParagraphs
    }
    
    /// Extract key points from response text for summary box
    private func extractKeyPoints(from text: String) -> [String] {
        print("🔍 extractKeyPoints: Starting extraction")
        var keyPoints: [String] = []
        let paragraphs = parseIntoParagraphs(text)
        print("   📝 Checking \(paragraphs.count) paragraphs for key points")
        
        // Look for bullet points or numbered lists in first few paragraphs
        let paragraphsToCheck = paragraphs.prefix(6)
        print("   🔎 Checking first \(paragraphsToCheck.count) paragraphs")
        
        for (index, paragraph) in paragraphsToCheck.enumerated() {
            // Skip headings
            if paragraph.hasPrefix("#") {
                print("   ⏭️  Skipping heading at index \(index)")
                continue
            }
            
            // Check if it's a list item
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Look for list patterns: "- ", "* ", "1. ", "2. ", etc.
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                var content = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                // Remove citations like [1], [2], [123] for cleaner summary
                content = content.replacingOccurrences(of: #"\[\d+\]"#, with: "", options: .regularExpression)
                // Also remove citations with spaces like [ 1 ] or [1 ] or [ 1]
                content = content.replacingOccurrences(of: #"\[\s*\d+\s*\]"#, with: "", options: .regularExpression)
                let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleanContent.count > 20 && cleanContent.count < 150 { // Reasonable length
                    keyPoints.append(cleanContent)
                    print("   ✅ Found bullet point \(keyPoints.count): \(cleanContent.prefix(50))...")
                } else {
                    print("   ❌ Bullet point at index \(index) rejected (length: \(cleanContent.count))")
                }
            } else if let firstChar = trimmed.first, firstChar.isNumber, trimmed.contains(". ") {
                // Numbered list: "1. ", "2. ", etc.
                if let dotIndex = trimmed.firstIndex(of: ".") {
                    var content = String(trimmed[trimmed.index(after: dotIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    // Remove citations like [1], [2], [123] for cleaner summary
                    content = content.replacingOccurrences(of: #"\[\d+\]"#, with: "", options: .regularExpression)
                    // Also remove citations with spaces like [ 1 ] or [1 ] or [ 1]
                    content = content.replacingOccurrences(of: #"\[\s*\d+\s*\]"#, with: "", options: .regularExpression)
                    let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleanContent.count > 20 && cleanContent.count < 150 {
                        keyPoints.append(cleanContent)
                        print("   ✅ Found numbered point \(keyPoints.count): \(cleanContent.prefix(50))...")
                    } else {
                        print("   ❌ Numbered point at index \(index) rejected (length: \(cleanContent.count))")
                    }
                }
            }
            
            // Stop at 5 key points max
            if keyPoints.count >= 5 {
                print("   🛑 Reached max key points (5)")
                break
            }
        }
        
        // If we didn't find list items, extract first few meaningful sentences
        if keyPoints.isEmpty && !paragraphs.isEmpty {
            print("   ⚠️  No list items found, extracting sentences from first paragraph")
            let firstParagraph = paragraphs.first ?? ""
            let sentences = firstParagraph.components(separatedBy: ". ")
                .map { sentence in
                    var cleanSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                    // Remove citations like [1], [2], [123]
                    cleanSentence = cleanSentence.replacingOccurrences(of: #"\[\d+\]"#, with: "", options: .regularExpression)
                    // Also remove citations with spaces
                    cleanSentence = cleanSentence.replacingOccurrences(of: #"\[\s*\d+\s*\]"#, with: "", options: .regularExpression)
                    return cleanSentence.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .filter { $0.count > 30 && $0.count < 200 }
            
            keyPoints = Array(sentences.prefix(3))
            print("   📝 Extracted \(keyPoints.count) sentences from first paragraph")
        }
        
        print("🎯 extractKeyPoints: Final result - \(keyPoints.count) key points")
        return keyPoints
    }
}

// MARK: - Paragraph View
struct ParagraphView: View {
    let paragraph: String
    let sources: [Source]
    let onSourceTap: (Source) -> Void
    var isFirstParagraph: Bool = false
    
    var body: some View {
        let parts = parseTextWithCitations(paragraph)
        
        Group {
        if isHeading(paragraph) {
                headingView
            } else if isBlockquote(paragraph) {
                blockquoteView
            } else if isCodeBlock(paragraph) {
                codeBlockView
            } else if isListItem(paragraph) {
                listItemView
            } else {
                regularParagraphView(parts: parts)
            }
        }
    }
    
    @ViewBuilder
    private var headingView: some View {
            let level = getHeadingLevel(paragraph)
            let headingText = removeHeadingMarkers(paragraph)
        let style = headingStyleForLevel(level)
            
            Group {
                if let attributed = try? AttributedString(markdown: headingText) {
                headingStyledText(Text(attributed), style: style)
            } else {
                headingStyledText(Text(headingText), style: style)
            }
        }
        .onAppear {
            print("🔍 ParagraphView: Heading detected - Level \(level)")
        }
    }
    
    private func headingStyleForLevel(_ level: Int) -> HeadingStyle {
        HeadingStyle(
            font: level == 1 ? DesignSystem.heading1Font() : (level == 2 ? DesignSystem.heading2Font() : DesignSystem.heading3Font()),
            tracking: level == 1 ? -0.5 : (level == 2 ? -0.3 : -0.2),
            gradientColors: level == 1 
                                    ? [Color.primary, Color.legalAccent.opacity(0.9)]
                                    : [Color.primary, Color.legalAccent.opacity(0.7)],
            topPadding: level == 1 ? 16 : (level == 2 ? 12 : 8),
            bottomPadding: level == 1 ? 8 : 6
        )
    }
    
    @ViewBuilder
    private func headingStyledText(_ text: Text, style: HeadingStyle) -> some View {
        text
            .font(style.font)
            .tracking(style.tracking)
                        .foregroundStyle(
                            LinearGradient(
                    colors: style.gradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .textSelection(.enabled)
            .padding(.top, style.topPadding)
            .padding(.bottom, style.bottomPadding)
                }
    
    private struct HeadingStyle {
        let font: Font
        let tracking: CGFloat
        let gradientColors: [Color]
        let topPadding: CGFloat
        let bottomPadding: CGFloat
    }
    
    @ViewBuilder
    private var blockquoteView: some View {
            let cleanedText = removeBlockquoteMarker(paragraph)
            let cleanedParts = parseTextWithCitations(cleanedText)
            
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(DesignSystem.accentColor.opacity(0.6))
                    .frame(width: 4)
                    .padding(.top, 4)
                
                InteractiveCitationView(
                    parts: cleanedParts,
                    sources: sources,
                    onSourceTap: onSourceTap,
                    fontSize: 16,
                    style: .italic
                )
            }
            .padding(.vertical, 8)
            .padding(.leading, 4)
            .background(
                DesignSystem.accentLight.opacity(0.3)
                    .cornerRadius(8)
            )
            .padding(.vertical, 4)
            }
    
    @ViewBuilder
    private var codeBlockView: some View {
            let cleanedText = removeCodeBlockMarkers(paragraph)
            let isInlineCode = !paragraph.hasPrefix("```")
            
                if isInlineCode {
                    Text(cleanedText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(DesignSystem.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Color(.secondarySystemBackground)
                                .cornerRadius(4)
                        )
                        .textSelection(.enabled)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(cleanedText)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.primary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .background(
                        Color(.secondarySystemBackground)
                            .cornerRadius(8)
                    )
                    .padding(.vertical, 4)
                    }
                }
    
    @ViewBuilder
    private var listItemView: some View {
            let cleanedText = removeListItemMarker(paragraph)
            let cleanedParts = parseTextWithCitations(cleanedText)
            let isNumbered = isNumberedListItem(paragraph)
            let listNumber = isNumbered ? getNumberedListNumber(paragraph) : nil
            
            HStack(alignment: .top, spacing: 12) {
                if let number = listNumber {
                    Text(number)
                        .foregroundColor(DesignSystem.accentColor)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(minWidth: 24, alignment: .trailing)
                        .padding(.top, 2)
                } else {
                    Text("•")
                        .foregroundColor(DesignSystem.accentColor)
                        .font(.system(size: 16, weight: .medium))
                        .padding(.top, 2)
                }
                
                InteractiveCitationView(
                    parts: cleanedParts,
                    sources: sources,
                    onSourceTap: onSourceTap
                )
            }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private func regularParagraphView(parts: [TextPart]) -> some View {
            InteractiveCitationView(
                parts: parts,
                sources: sources,
                onSourceTap: onSourceTap,
            fontSize: isFirstParagraph ? 18 : 17
        )
    }
    
    private func isHeading(_ text: String) -> Bool {
        text.hasPrefix("# ") || text.hasPrefix("## ") || text.hasPrefix("### ")
    }
    
    private func isListItem(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Bullet lists
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            print("   ✓ isListItem: Detected bullet list item")
            return true
        }
        // Numbered lists (1., 2., 10., etc.)
        if let firstChar = trimmed.first, firstChar.isNumber {
            let pattern = #"^\d+\.\s"#
            if trimmed.range(of: pattern, options: .regularExpression) != nil {
                print("   ✓ isListItem: Detected numbered list item")
                return true
            }
        }
        return false
    }
    
    private func isNumberedListItem(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let firstChar = trimmed.first, firstChar.isNumber {
            let pattern = #"^\d+\.\s"#
            let isNumbered = trimmed.range(of: pattern, options: .regularExpression) != nil
            if isNumbered {
                print("   ✓ isNumberedListItem: Confirmed numbered list item")
            }
            return isNumbered
        }
        return false
    }
    
    private func isBlockquote(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let isQuote = trimmed.hasPrefix("> ")
        if isQuote {
            print("   ✓ isBlockquote: Detected blockquote")
        }
        return isQuote
    }
    
    private func isCodeBlock(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let isCode = trimmed.hasPrefix("```") || (trimmed.hasPrefix("`") && trimmed.hasSuffix("`") && trimmed.count > 2)
        if isCode {
            let type = trimmed.hasPrefix("```") ? "block" : "inline"
            print("   ✓ isCodeBlock: Detected \(type) code")
        }
        return isCode
    }
    
    private func getNumberedListNumber(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^(\d+)\.\s"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.count)),
           match.numberOfRanges > 1,
           let range = Range(match.range(at: 1), in: trimmed) {
            let number = String(trimmed[range])
            print("   ✓ getNumberedListNumber: Extracted number '\(number)'")
            return number
        }
        return nil
    }
    
    private func getHeadingLevel(_ text: String) -> Int {
        if text.hasPrefix("# ") {
            return 1
        } else if text.hasPrefix("## ") {
            return 2
        } else if text.hasPrefix("### ") {
            return 3
        }
        return 2 // Default
    }
    
    private func removeHeadingMarkers(_ text: String) -> String {
        text.replacingOccurrences(of: "^###? ?", with: "", options: .regularExpression)
    }
    
    private func removeListItemMarker(_ text: String) -> String {
        text.replacingOccurrences(of: "^[-*] |^\\d+\\. ", with: "", options: .regularExpression)
    }
    
    private func removeBlockquoteMarker(_ text: String) -> String {
        text.replacingOccurrences(of: "^> ", with: "", options: .regularExpression)
    }
    
    private func removeCodeBlockMarkers(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove ``` markers for code blocks
        if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
            if cleaned.hasSuffix("```") {
                cleaned = String(cleaned.dropLast(3))
            }
        } else if cleaned.hasPrefix("`") && cleaned.hasSuffix("`") && cleaned.count > 2 {
            // Inline code
            cleaned = String(cleaned.dropFirst().dropLast())
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    @ViewBuilder
    private func buildTextWithInteractiveCitations(parts: [TextPart]) -> some View {
        InteractiveCitationView(parts: parts, sources: sources, onSourceTap: onSourceTap)
    }
    
    func parseTextWithCitations(_ text: String) -> [TextPart] {
        var parts: [TextPart] = []
        
        let nsString = text as NSString
        var matches: [(range: NSRange, type: String, value: String)] = []
        
        // Try to find citations using the most common pattern first: [1]
        let primaryPattern = "\\[(\\d+)\\]"
        if let citationRegex = try? NSRegularExpression(pattern: primaryPattern) {
            citationRegex.enumerateMatches(in: text, range: NSRange(location: 0, length: nsString.length)) { match, _, _ in
                if let match = match, match.numberOfRanges > 1, let r = Range(match.range(at: 1), in: text) {
                    let citationNumber = String(text[r])
                    matches.append((match.range, "citation", citationNumber))
                }
            }
        }
        
        // If no matches with primary pattern, try pattern with spaces
        if matches.isEmpty {
            let spacedPattern = "\\[\\s*(\\d+)\\s*\\]"
            if let citationRegex = try? NSRegularExpression(pattern: spacedPattern) {
                citationRegex.enumerateMatches(in: text, range: NSRange(location: 0, length: nsString.length)) { match, _, _ in
                    if let match = match, match.numberOfRanges > 1, let r = Range(match.range(at: 1), in: text) {
                        let citationNumber = String(text[r])
                        matches.append((match.range, "citation", citationNumber))
                    }
                }
            }
        }
        
        // If no citations found, return entire text as single part
        guard !matches.isEmpty else {
            return [.text(text)]
        }
        
        // Sort matches by location
        matches.sort { $0.range.location < $1.range.location }
        
        var currentIndex = 0
        
        for match in matches {
            // Prevent overlapping matches (simple check)
            if match.range.location < currentIndex { continue }
            
            // Text before match
            if match.range.location > currentIndex {
                let range = NSRange(location: currentIndex, length: match.range.location - currentIndex)
                let textBefore = nsString.substring(with: range)
                if !textBefore.isEmpty {
                    parts.append(.text(textBefore))
                }
            }
            
            // The match itself - citation
            if match.type == "citation", let index = Int(match.value) {
                parts.append(.citation(index))
            }
            
            currentIndex = match.range.location + match.range.length
        }
        
        // Remaining text after last citation
        if currentIndex < nsString.length {
            let remainingText = nsString.substring(from: currentIndex)
            if !remainingText.isEmpty {
                parts.append(.text(remainingText))
            }
        }
        
        // Ensure we always return at least one part
        return parts.isEmpty ? [.text(text)] : parts
    }
}



struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Streaming Message View
struct StreamingMessageView: View {
    let text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                // Article-style streaming content with proper Markdown formatting
                Group {
                    if let attributed = try? AttributedString(markdown: text) {
                        Text(attributed)
                            .font(DesignSystem.bodyFont())
                            .foregroundColor(.primary)
                            .lineSpacing(DesignSystem.bodyLineSpacing)
                            .textSelection(.enabled)
                    } else {
                        Text(text)
                            .font(DesignSystem.bodyFont())
                            .foregroundColor(.primary)
                            .lineSpacing(DesignSystem.bodyLineSpacing)
                            .textSelection(.enabled)
                    }
                }
                
                // Typing indicator
                HStack(spacing: 6) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.secondary.opacity(0.5))
                            .frame(width: 6, height: 6)
                            .scaleEffect(1.0)
                            .opacity(0.6)
                    }
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }
}


// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: 0) {
            // Sample user message
            MessageBubbleView(
                message: {
                    let context = PersistenceController.preview.container.viewContext
                    let message = Message(context: context)
                    message.content = "What are the symptoms of diabetes?"
                    message.role = "user"
                    return message
                }(),
                onSourceTap: { _ in },
                onCopy: {},
                onShare: {},
                onEdit: nil
            )
            
            // Sample assistant message with citations
            MessageBubbleView(
                message: {
                    let context = PersistenceController.preview.container.viewContext
                    let message = Message(context: context)
                    message.content = "Diabetes symptoms include increased thirst [1], frequent urination [1], and fatigue [2]. Consult a healthcare provider for diagnosis [3]."
                    message.role = "assistant"
                    message.sourcesJSON = [
                        Source(title: "Mayo Clinic - Diabetes", url: "https://www.mayoclinic.org/diabetes", snippet: "Comprehensive diabetes information"),
                        Source(title: "CDC Diabetes Guide", url: "https://www.cdc.gov/diabetes", snippet: "CDC diabetes resources"),
                        Source(title: "NIH Diabetes Research", url: "https://www.nih.gov/diabetes", snippet: "Latest diabetes research")
                    ].toJSONString()
                    return message
                }(),
                onSourceTap: { source in print("Tapped: \(source.title)") },
                onCopy: {},
                onShare: {},
                onEdit: nil
            )
        }
    }
}
