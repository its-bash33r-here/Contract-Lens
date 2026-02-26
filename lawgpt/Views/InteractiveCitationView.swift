//
//  InteractiveCitationView.swift
//  lawgpt
//
//  Created by Bash33r on 01/12/25.
//

import SwiftUI
import SafariServices

// MARK: - Text Part Enum
enum TextPart {
    case text(String)
    case citation(Int)
}

/// View that renders text with interactive citation buttons inline
struct InteractiveCitationView: View {
    let parts: [TextPart]
    let sources: [Source]
    let onSourceTap: (Source) -> Void
    var fontSize: CGFloat = 17 // Default body font size
    var style: FontStyle = .regular // Font style (regular, italic)
    @State private var showSafari = false
    @State private var safariURL: URL?
    
    enum FontStyle {
        case regular
        case italic
    }
    
    var body: some View {
        // Build NSAttributedString with links for citations (for UITextView)
        let nsAttributedText = buildNSAttributedString()
        
        // Use UITextView for better text selection support with links
        SelectableTextView(
            attributedText: nsAttributedText,
            showSafari: $showSafari,
            safariURL: $safariURL
        )
        .frame(maxWidth: .infinity, alignment: .leading) // Constrain to available width
        .fixedSize(horizontal: false, vertical: true) // Size to content vertically
        .onAppear {
            print("✅ InteractiveCitationView: Rendered with \(nsAttributedText.length) characters")
            print("   Font size: \(fontSize)pt")
            print("   Style: \(style == .italic ? "italic" : "regular")")
            print("   Parts count: \(parts.count)")
        }
        .sheet(isPresented: $showSafari) {
            if let url = safariURL {
                SafariView(url: url)
            }
        }
    }
    
    private func buildNSAttributedString() -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        // If no parts, return empty attributed string
        if parts.isEmpty {
            return NSAttributedString()
        }
        
        for part in parts {
            switch part {
            case .text(let str):
                // Don't skip empty strings if they're the only content
                if str.isEmpty && parts.count == 1 {
                    return NSAttributedString()
                }
                guard !str.isEmpty else {
                    continue
                }
                
                // Parse markdown and apply formatting (for **bold**, _italics_, etc.)
                let textAttributed = parseMarkdownToNSAttributedString(str, baseFontSize: fontSize, baseStyle: style)
                result.append(textAttributed)
                
            case .citation(let index):
                let citationText = " [\(index)]"
                
                if index > 0 && index <= sources.count {
                    let source = sources[index - 1] // Sources are 1-indexed
                    
                    // Add citation text
                    let citationAttributed = NSMutableAttributedString(string: citationText)
                    let citationRange = NSRange(location: 0, length: citationText.count)
                    
                    // Make citation tappable by adding a link to the source URL
                    if let url = URL(string: source.url) {
                        citationAttributed.addAttribute(.link, value: url, range: citationRange)
                    } else {
                        // Fallback: create a custom URL scheme if source.url is invalid
                        if let fallbackURL = URL(string: "lawgpt://citation/\(index)") {
                            citationAttributed.addAttribute(.link, value: fallbackURL, range: citationRange)
                        }
                    }
                    
                    // Style the citation - make it highly visible
                    let font = UIFont.boldSystemFont(ofSize: 12) // Match caption font
                    citationAttributed.addAttribute(.font, value: font, range: citationRange)
                    citationAttributed.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: citationRange)
                    citationAttributed.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: citationRange)
                    
                    result.append(citationAttributed)
                } else {
                    // Invalid citation - style but still make visible
                    let citationAttributed = NSMutableAttributedString(string: citationText)
                    let citationRange = NSRange(location: 0, length: citationText.count)
                    let font = UIFont.boldSystemFont(ofSize: 12)
                    citationAttributed.addAttribute(.font, value: font, range: citationRange)
                    citationAttributed.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: citationRange)
                    citationAttributed.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: citationRange)
                    result.append(citationAttributed)
                }
            }
        }
        
        // Set paragraph style for proper line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = DesignSystem.bodyLineSpacing
        result.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: result.length))
        
        return result
    }
    
    /// Parse markdown formatting (**bold**, _italic_) and convert to NSAttributedString
    private func parseMarkdownToNSAttributedString(_ text: String, baseFontSize: CGFloat = 17, baseStyle: FontStyle = .regular) -> NSMutableAttributedString {
        // Build result string by processing markdown and tracking ranges
        var resultString = ""
        var boldRanges: [NSRange] = []
        var italicRanges: [NSRange] = []
        
        var currentIndex = 0
        let nsString = text as NSString
        let textLength = text.count
        
        // Find all bold and italic matches with their positions
        var allMatches: [(range: NSRange, type: String, contentRange: NSRange)] = []
        
        // Find bold matches: **text**
        let boldPattern = "\\*\\*([^*]+?)\\*\\*"
        if let boldRegex = try? NSRegularExpression(pattern: boldPattern, options: []) {
            let matches = boldRegex.matches(in: text, options: [], range: NSRange(location: 0, length: textLength))
            for match in matches {
                if match.numberOfRanges >= 2 {
                    let fullRange = match.range(at: 0)
                    let contentRange = match.range(at: 1)
                    allMatches.append((range: fullRange, type: "bold", contentRange: contentRange))
                }
            }
        }
        
        // Find italic matches: _text_
        let italicPattern = "_(.+?)_"
        if let italicRegex = try? NSRegularExpression(pattern: italicPattern, options: []) {
            let matches = italicRegex.matches(in: text, options: [], range: NSRange(location: 0, length: textLength))
            for match in matches {
                if match.numberOfRanges >= 2 {
                    let fullRange = match.range(at: 0)
                    let contentRange = match.range(at: 1)
                    // Check if this italic range overlaps with any bold range
                    let overlapsWithBold = allMatches.contains { $0.type == "bold" && NSIntersectionRange($0.range, fullRange).length > 0 }
                    if !overlapsWithBold {
                        allMatches.append((range: fullRange, type: "italic", contentRange: contentRange))
                    }
                }
            }
        }
        
        // Sort matches by position
        allMatches.sort { $0.range.location < $1.range.location }
        
        // Build result string by removing markers and tracking ranges
        for match in allMatches {
            // Add text before this match
            if match.range.location > currentIndex {
                let beforeRange = NSRange(location: currentIndex, length: match.range.location - currentIndex)
                resultString += nsString.substring(with: beforeRange)
            }
            
            // Add content (without markers)
            let content = nsString.substring(with: match.contentRange)
            let contentStartIndex = resultString.count
            resultString += content
            
            // Record the range in the result string
            let resultRange = NSRange(location: contentStartIndex, length: match.contentRange.length)
            if match.type == "bold" {
                boldRanges.append(resultRange)
            } else if match.type == "italic" {
                italicRanges.append(resultRange)
            }
            
            currentIndex = match.range.location + match.range.length
        }
        
        // Add remaining text after last match
        if currentIndex < textLength {
            let remainingRange = NSRange(location: currentIndex, length: textLength - currentIndex)
            resultString += nsString.substring(with: remainingRange)
        }
        
        // If no matches found, use original text
        if allMatches.isEmpty {
            resultString = text
        }
        
        // Build the attributed string
        let result = NSMutableAttributedString(string: resultString)
        let fullRange = NSRange(location: 0, length: resultString.count)
        
        // Apply base font style (regular or italic)
        let baseFont: UIFont
        if baseStyle == .italic {
            if let descriptor = UIFont.systemFont(ofSize: baseFontSize).fontDescriptor.withSymbolicTraits(.traitItalic) {
                baseFont = UIFont(descriptor: descriptor, size: baseFontSize)
            } else {
                baseFont = UIFont.italicSystemFont(ofSize: baseFontSize)
            }
        } else {
            baseFont = UIFont.systemFont(ofSize: baseFontSize)
        }
        
        result.addAttribute(.font, value: baseFont, range: fullRange)
        result.addAttribute(.foregroundColor, value: UIColor.label, range: fullRange)
        
        // Apply bold formatting
        for boldRange in boldRanges {
            if boldRange.location + boldRange.length <= result.length {
                // Check if bold range overlaps with italic - if so, use bold-italic font
                let hasItalic = italicRanges.contains { NSIntersectionRange($0, boldRange).length > 0 }
                
                if hasItalic {
                    // Bold + Italic
                    if let descriptor = baseFont.fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic]) {
                        result.addAttribute(.font, value: UIFont(descriptor: descriptor, size: baseFontSize), range: boldRange)
                    } else {
                        result.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: baseFontSize), range: boldRange)
                    }
                } else {
                    // Just bold
                    result.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: baseFontSize), range: boldRange)
                }
            }
        }
        
        // Apply italic formatting (only for non-bold ranges)
        let italicFont: UIFont
        if let descriptor = UIFont.systemFont(ofSize: baseFontSize).fontDescriptor.withSymbolicTraits(.traitItalic) {
            italicFont = UIFont(descriptor: descriptor, size: baseFontSize)
        } else {
            italicFont = UIFont.italicSystemFont(ofSize: baseFontSize)
        }
        
        for italicRange in italicRanges {
            if italicRange.location + italicRange.length <= result.length {
                // Check if italic range overlaps with bold - if already handled above, skip
                let hasBold = boldRanges.contains { NSIntersectionRange($0, italicRange).length > 0 }
                if !hasBold {
                    result.addAttribute(.font, value: italicFont, range: italicRange)
                }
            }
        }
        
        return result
    }
    
    // Keep buildAttributedString for potential future use, but currently unused
    private func buildAttributedString() -> AttributedString {
        var result = AttributedString()
        
        // If no parts, return empty attributed string
        if parts.isEmpty {
            return AttributedString("")
        }
        
        for part in parts {
            switch part {
            case .text(let str):
                // Don't skip empty strings if they're the only content
                if str.isEmpty && parts.count == 1 {
                    return AttributedString("")
                }
                guard !str.isEmpty else { continue }
                
                // Parse markdown in text (for **bold**, _italics_, etc.)
                if let markdownAttributed = try? AttributedString(markdown: str) {
                    result.append(markdownAttributed)
                } else {
                    result.append(AttributedString(str))
                }
                
            case .citation(let index):
                let citationText = " [\(index)]"
                var citationAttributed = AttributedString(citationText)
                
                // Get the full range of the citation text
                let citationRange = citationAttributed.startIndex..<citationAttributed.endIndex
                
                if index > 0 && index <= sources.count {
                    let source = sources[index - 1] // Sources are 1-indexed
                    
                    // Make citation tappable by adding a link to the source URL
                    // Use the actual source URL so tapping opens the link
                    if let url = URL(string: source.url) {
                        citationAttributed[citationRange].link = url
                    } else {
                        // Fallback: create a custom URL scheme if source.url is invalid
                        citationAttributed[citationRange].link = URL(string: "lawgpt://citation/\(index)")
                    }
                    
                    // Style the citation using AttributeContainer - make it highly visible
                    var attributes = AttributeContainer()
                    attributes.font = DesignSystem.captionFont().bold()
                    attributes.foregroundColor = Color.legalAccent
                    attributes.underlineStyle = .single
                    // Ensure visibility
                    citationAttributed[citationRange].mergeAttributes(attributes)
                } else {
                    // Invalid citation - style but still make visible
                    var attributes = AttributeContainer()
                    attributes.font = DesignSystem.captionFont().bold()
                    attributes.foregroundColor = Color.secondary
                    attributes.underlineStyle = .single
                    citationAttributed[citationRange].mergeAttributes(attributes)
                }
                
                result.append(citationAttributed)
            }
        }
        
        // Return result - always return something
        return result
    }
}
