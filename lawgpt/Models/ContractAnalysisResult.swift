//
//  ContractAnalysisResult.swift
//  lawgpt
//
//  Data models for the ClauseGuard AI contract analysis feature.
//

import Foundation

/// Full AI analysis result returned by the contract scanner
struct ContractAnalysisResult: Codable {
    let safetyScore: Int          // 0-100 (100 = fully safe)
    let summary: String           // One-sentence vibe summary
    let analysis: [ContractClause]

    var dangerClauses: [ContractClause] { analysis.filter { $0.type == .danger } }
    var safeClauses: [ContractClause]   { analysis.filter { $0.type == .safe } }

    /// Human-readable label for the safety score tier
    var scoreLabel: String {
        switch safetyScore {
        case 80...100: return "Low Risk"
        case 60..<80:  return "Moderate Risk"
        case 40..<60:  return "High Risk"
        default:       return "Dangerous"
        }
    }

    enum CodingKeys: String, CodingKey {
        case safetyScore = "safety_score"
        case summary
        case analysis
    }
}

/// A single analysed clause — either a red flag or a positive clause
struct ContractClause: Codable, Identifiable {
    let id: UUID
    let type: ClauseType
    let title: String
    let quote: String       // Exact text from contract
    let explanation: String // Plain-English explanation
    let fix: String         // Suggested replacement / action

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id          = UUID()
        type        = try container.decode(ClauseType.self, forKey: .type)
        title       = try container.decode(String.self, forKey: .title)
        quote       = try container.decode(String.self, forKey: .quote)
        explanation = try container.decode(String.self, forKey: .explanation)
        fix         = try container.decode(String.self, forKey: .fix)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type,        forKey: .type)
        try container.encode(title,       forKey: .title)
        try container.encode(quote,       forKey: .quote)
        try container.encode(explanation, forKey: .explanation)
        try container.encode(fix,         forKey: .fix)
    }

    enum CodingKeys: String, CodingKey {
        case type, title, quote, explanation, fix
    }

    enum ClauseType: String, Codable {
        case danger
        case safe
    }
}
