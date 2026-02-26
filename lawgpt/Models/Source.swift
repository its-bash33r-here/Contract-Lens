//
//  Source.swift
//  lawgpt
//
//  Created by Bash33r on 01/12/25.
//

import Foundation

/// Represents a source/citation from legal content
struct Source: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let url: String
    let snippet: String?
    let favicon: String?
    
    init(id: UUID = UUID(), title: String, url: String, snippet: String? = nil, favicon: String? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.snippet = snippet
        self.favicon = favicon
    }
    
    /// Extract domain from URL for display
    var domain: String {
        guard let urlObj = URL(string: url),
              let host = urlObj.host else {
            return url
        }
        return host.replacingOccurrences(of: "www.", with: "")
    }
    
    /// Get favicon URL from Google's favicon service
    var faviconURL: URL? {
        if let favicon = favicon, let url = URL(string: favicon) {
            return url
        }
        // Fallback to Google's favicon service
        return URL(string: "https://www.google.com/s2/favicons?domain=\(domain)&sz=64")
    }
}

// MARK: - Source Array Encoding/Decoding Helpers
extension Array where Element == Source {
    /// Convert sources array to JSON string for Core Data storage
    func toJSONString() -> String? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// Create sources array from JSON string
    static func fromJSONString(_ jsonString: String?) -> [Source] {
        guard let jsonString = jsonString,
              let data = jsonString.data(using: .utf8) else {
            return []
        }
        let decoder = JSONDecoder()
        return (try? decoder.decode([Source].self, from: data)) ?? []
    }
}

// MARK: - Message Extension for Sources
extension Message {
    /// Get sources from the stored JSON
    var sources: [Source] {
        return [Source].fromJSONString(sourcesJSON)
    }
    
    /// Set sources and encode to JSON
    func setSources(_ sources: [Source]) {
        self.sourcesJSON = sources.toJSONString()
    }
}

// MARK: - Follow-Up Suggestions Array Encoding/Decoding Helpers
extension Array where Element == String {
    /// Convert follow-up suggestions array to JSON string for Core Data storage
    func toJSONString() -> String? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// Create follow-up suggestions array from JSON string
    static func fromJSONString(_ jsonString: String?) -> [String] {
        guard let jsonString = jsonString,
              let data = jsonString.data(using: .utf8) else {
            return []
        }
        let decoder = JSONDecoder()
        return (try? decoder.decode([String].self, from: data)) ?? []
    }
}

// MARK: - Message Extension for Follow-Up Suggestions
extension Message {
    /// Get follow-up suggestions from the stored JSON
    var followUpSuggestions: [String] {
        return [String].fromJSONString(followUpSuggestionsJSON)
    }
    
    /// Set follow-up suggestions and encode to JSON
    func setFollowUpSuggestions(_ suggestions: [String]) {
        self.followUpSuggestionsJSON = suggestions.toJSONString()
    }
}
