//
//  ExportService.swift
//  lawgpt
//
//  Created by Bash33r on 01/12/25.
//

import Foundation
import PDFKit
import UIKit

enum ExportFormat {
    case pdf
    case markdown
    case plainText
}

/// Service for exporting conversations to various formats
@MainActor
class ExportService {
    
    /// Export a conversation to the specified format
    func exportConversation(
        _ conversation: Conversation,
        messages: [Message],
        format: ExportFormat
    ) throws -> URL {
        switch format {
        case .pdf:
            return try exportToPDF(conversation: conversation, messages: messages)
        case .markdown:
            return try exportToMarkdown(conversation: conversation, messages: messages)
        case .plainText:
            return try exportToPlainText(conversation: conversation, messages: messages)
        }
    }
    
    /// Export a single message to the specified format
    func exportMessage(
        _ message: Message,
        format: ExportFormat
    ) throws -> URL {
        switch format {
        case .pdf:
            return try exportMessageToPDF(message: message)
        case .markdown:
            return try exportMessageToMarkdown(message: message)
        case .plainText:
            return try exportMessageToPlainText(message: message)
        }
    }
    
    // MARK: - PDF Export
    
    private func exportToPDF(conversation: Conversation, messages: [Message]) throws -> URL {
        let pdfMetaData = [
            kCGPDFContextCreator: "ClauseGuard",
            kCGPDFContextAuthor: "ClauseGuard AI",
            kCGPDFContextTitle: conversation.title ?? "Legal Conversation"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth = 8.5 * 72.0
        let pageHeight = 11 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            var yPosition: CGFloat = 72 // Start 1 inch from top
            
            // Title
            let title = conversation.title ?? "Legal Conversation"
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.label
            ]
            let titleSize = title.size(withAttributes: titleAttributes)
            title.draw(at: CGPoint(x: 72, y: yPosition), withAttributes: titleAttributes)
            yPosition += titleSize.height + 20
            
            // Date
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            let dateString = "Date: \(dateFormatter.string(from: conversation.createdAt ?? Date()))"
            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.secondaryLabel
            ]
            dateString.draw(at: CGPoint(x: 72, y: yPosition), withAttributes: dateAttributes)
            yPosition += 30
            
            // Messages
            for message in messages {
                if yPosition > pageHeight - 100 {
                    context.beginPage()
                    yPosition = 72
                }
                
                let role = message.role == "user" ? "Question" : "Response"
                let roleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 14),
                    .foregroundColor: message.role == "user" ? UIColor.systemBlue : UIColor.label
                ]
                role.draw(at: CGPoint(x: 72, y: yPosition), withAttributes: roleAttributes)
                yPosition += 20
                
                // Message content
                let content = message.content ?? ""
                let contentAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12),
                    .foregroundColor: UIColor.label
                ]
                // Calculate height needed first
                let contentSize = content.boundingRect(
                    with: CGSize(width: pageWidth - 144, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: contentAttributes,
                    context: nil
                )
                
                // Draw content
                let contentRect = CGRect(x: 72, y: yPosition, width: pageWidth - 144, height: contentSize.height)
                content.draw(in: contentRect, withAttributes: contentAttributes)
                
                yPosition += contentSize.height + 20
                
                // Sources
                if !message.sources.isEmpty {
                    yPosition += 10
                    let sourcesTitle = "Sources:"
                    sourcesTitle.draw(at: CGPoint(x: 72, y: yPosition), withAttributes: roleAttributes)
                    yPosition += 20
                    
                    for (index, source) in message.sources.enumerated() {
                        let sourceText = "[\(index + 1)] \(source.title)\n   \(source.url)"
                        let sourceAttributes: [NSAttributedString.Key: Any] = [
                            .font: UIFont.systemFont(ofSize: 10),
                            .foregroundColor: UIColor.secondaryLabel
                        ]
                        let sourceRect = CGRect(x: 72, y: yPosition, width: pageWidth - 144, height: 50)
                        sourceText.draw(in: sourceRect, withAttributes: sourceAttributes)
                        yPosition += 30
                    }
                }
                
                yPosition += 20
            }
        }
        
        // Save to temporary file
        let fileName = "\(conversation.title ?? "conversation")_\(Date().timeIntervalSince1970).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url)
        
        return url
    }
    
    private func exportMessageToPDF(message: Message) throws -> URL {
        // Similar to exportToPDF but for single message
        let pdfMetaData = [
            kCGPDFContextCreator: "LawGPT",
            kCGPDFContextAuthor: "LawGPT Legal Assistant",
            kCGPDFContextTitle: "Legal Information"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth = 8.5 * 72.0
        let pageHeight = 11 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            var yPosition: CGFloat = 72
            
            let content = message.content ?? ""
            let contentAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.label
            ]
            // Calculate content size first
            let contentSize = content.boundingRect(
                with: CGSize(width: pageWidth - 144, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: contentAttributes,
                context: nil
            )
            
            // Draw content
            let contentRect = CGRect(x: 72, y: yPosition, width: pageWidth - 144, height: contentSize.height)
            content.draw(in: contentRect, withAttributes: contentAttributes)
            
            yPosition += contentSize.height + 20
            
            // Sources
            if !message.sources.isEmpty {
                yPosition = pageHeight - 200
                let sourcesTitle = "Sources:"
                let titleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 14),
                    .foregroundColor: UIColor.label
                ]
                sourcesTitle.draw(at: CGPoint(x: 72, y: yPosition), withAttributes: titleAttributes)
                yPosition += 20
                
                for (index, source) in message.sources.enumerated() {
                    let sourceText = "[\(index + 1)] \(source.title)\n   \(source.url)"
                    let sourceAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 10),
                        .foregroundColor: UIColor.secondaryLabel
                    ]
                    let sourceRect = CGRect(x: 72, y: yPosition, width: pageWidth - 144, height: 50)
                    sourceText.draw(in: sourceRect, withAttributes: sourceAttributes)
                    yPosition += 30
                }
            }
        }
        
        let fileName = "legal_info_\(Date().timeIntervalSince1970).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url)
        
        return url
    }
    
    // MARK: - Markdown Export
    
    private func exportToMarkdown(conversation: Conversation, messages: [Message]) throws -> URL {
        var markdown = "# \(conversation.title ?? "Legal Conversation")\n\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        markdown += "**Date:** \(dateFormatter.string(from: conversation.createdAt ?? Date()))\n\n"
        markdown += "---\n\n"
        
        for message in messages {
            let role = message.role == "user" ? "## Question" : "## Response"
            markdown += "\(role)\n\n"
            markdown += "\(message.content ?? "")\n\n"
            
            if !message.sources.isEmpty {
                markdown += "### Sources\n\n"
                for (index, source) in message.sources.enumerated() {
                    markdown += "\(index + 1). [\(source.title)](\(source.url))\n"
                }
                markdown += "\n"
            }
            
            markdown += "---\n\n"
        }
        
        let fileName = "\(conversation.title ?? "conversation")_\(Date().timeIntervalSince1970).md"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try markdown.write(to: url, atomically: true, encoding: .utf8)
        
        return url
    }
    
    private func exportMessageToMarkdown(message: Message) throws -> URL {
        var markdown = "# Legal Information\n\n"
        markdown += "\(message.content ?? "")\n\n"
        
        if !message.sources.isEmpty {
            markdown += "## Sources\n\n"
            for (index, source) in message.sources.enumerated() {
                markdown += "\(index + 1). [\(source.title)](\(source.url))\n"
            }
        }
        
        let fileName = "legal_info_\(Date().timeIntervalSince1970).md"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try markdown.write(to: url, atomically: true, encoding: .utf8)
        
        return url
    }
    
    // MARK: - Plain Text Export
    
    private func exportToPlainText(conversation: Conversation, messages: [Message]) throws -> URL {
        var text = "\(conversation.title ?? "Legal Conversation")\n"
        text += String(repeating: "=", count: conversation.title?.count ?? 20) + "\n\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        text += "Date: \(dateFormatter.string(from: conversation.createdAt ?? Date()))\n\n"
        
        for message in messages {
            let role = message.role == "user" ? "QUESTION" : "RESPONSE"
            text += "\n\(role)\n"
            text += String(repeating: "-", count: role.count) + "\n\n"
            text += "\(message.content ?? "")\n\n"
            
            if !message.sources.isEmpty {
                text += "Sources:\n"
                for (index, source) in message.sources.enumerated() {
                    text += "  [\(index + 1)] \(source.title)\n"
                    text += "      \(source.url)\n"
                }
                text += "\n"
            }
        }
        
        let fileName = "\(conversation.title ?? "conversation")_\(Date().timeIntervalSince1970).txt"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try text.write(to: url, atomically: true, encoding: .utf8)
        
        return url
    }
    
    private func exportMessageToPlainText(message: Message) throws -> URL {
        var text = "Legal Information\n"
        text += String(repeating: "=", count: 20) + "\n\n"
        text += "\(message.content ?? "")\n\n"
        
        if !message.sources.isEmpty {
            text += "Sources:\n"
            for (index, source) in message.sources.enumerated() {
                text += "  [\(index + 1)] \(source.title)\n"
                text += "      \(source.url)\n"
            }
        }
        
        let fileName = "legal_info_\(Date().timeIntervalSince1970).txt"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try text.write(to: url, atomically: true, encoding: .utf8)
        
        return url
    }
}

