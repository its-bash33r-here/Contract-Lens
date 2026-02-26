//
//  FlagCardView.swift
//  lawgpt
//
//  Expandable card displaying a single contract clause analysis result.
//

import SwiftUI

struct FlagCardView: View {
    let clause: ContractClause
    @State private var isExpanded: Bool = false

    private var isRed: Bool { clause.type == .danger }

    private var accentColor: Color {
        isRed ? Color(red: 0.9, green: 0.15, blue: 0.15) : Color(red: 0.15, green: 0.75, blue: 0.47)
    }
    private var bgColor: Color {
        isRed
            ? Color(red: 0.9, green: 0.15, blue: 0.15).opacity(0.08)
            : Color(red: 0.15, green: 0.75, blue: 0.47).opacity(0.08)
    }
    private var iconName: String { isRed ? "exclamationmark.triangle.fill" : "checkmark.shield.fill" }
    private var typeLabel: String { isRed ? "RED FLAG" : "POSITIVE CLAUSE" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row — always visible
            Button(action: {
                HapticManager.shared.lightImpact()
                withAnimation(.easeInOut(duration: 0.28)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(accentColor)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(typeLabel)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(accentColor)
                            .tracking(1.2)

                        Text(clause.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 18)
            }
            .buttonStyle(.plain)

            if isExpanded {
                expandedDetail
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(bgColor)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(accentColor.opacity(0.25), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var expandedDetail: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
                .background(accentColor.opacity(0.3))
                .padding(.horizontal, 18)

            // Quote from contract
            VStack(alignment: .leading, spacing: 6) {
                Label("From the contract", systemImage: "text.quote")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)

                Text("\"\(clause.quote)\"")
                    .font(.system(size: 13, design: .serif))
                    .foregroundColor(.primary.opacity(0.8))
                    .italic()
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 18)

            // Explanation
            VStack(alignment: .leading, spacing: 6) {
                Label(isRed ? "Why this is dangerous" : "Why this is good",
                      systemImage: "lightbulb.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(accentColor)

                Text(clause.explanation)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .lineSpacing(5)
            }
            .padding(.horizontal, 18)

            // Fix / action
            fixSection
        }
    }

    @ViewBuilder
    private var fixSection: some View {
        let fixColor = isRed ? Color(red: 1.0, green: 0.55, blue: 0.0) : accentColor
        VStack(alignment: .leading, spacing: 6) {
            Label(isRed ? "Suggested fix" : "What to keep",
                  systemImage: isRed ? "pencil.and.list.clipboard" : "hand.thumbsup.fill")
                .font(.caption.weight(.semibold))
                .foregroundColor(fixColor)

            Text(clause.fix)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .lineSpacing(5)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(fixColor.opacity(0.08))
                )

            Button(action: {
                UIPasteboard.general.string = clause.fix
                HapticManager.shared.success()
            }) {
                Label("Copy to clipboard", systemImage: "doc.on.doc")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(accentColor)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            FlagCardView(clause: ContractClause(
                id: UUID(),
                type: .danger,
                title: "Aggressive Non-Compete",
                quote: "Employee agrees not to work in any competing industry for 5 years following termination.",
                explanation: "A 5-year non-compete covering an entire industry is unusually broad and likely unenforceable in many states, but defending against it in court is costly.",
                fix: "Replace with: 'Employee agrees not to directly solicit clients of Company for 12 months following termination within [specific city/region].'"
            ))
            FlagCardView(clause: ContractClause(
                id: UUID(),
                type: .safe,
                title: "Net-15 Payment Terms",
                quote: "Client agrees to pay all invoices within 15 days of receipt.",
                explanation: "Net-15 is favourable — faster than industry-standard Net-30, improving your cash flow.",
                fix: "Keep this clause as-is. Ensure it also includes a late payment penalty clause."
            ))
        }
        .padding()
    }
}

// MARK: - UUID init workaround for preview
extension ContractClause {
    init(id: UUID, type: ContractClause.ClauseType, title: String, quote: String, explanation: String, fix: String) {
        self = try! JSONDecoder().decode(ContractClause.self, from: JSONEncoder().encode(
            _ContractClausePreviewHelper(type: type.rawValue, title: title, quote: quote, explanation: explanation, fix: fix)
        ))
    }
}

private struct _ContractClausePreviewHelper: Encodable {
    let type: String
    let title: String
    let quote: String
    let explanation: String
    let fix: String
}
