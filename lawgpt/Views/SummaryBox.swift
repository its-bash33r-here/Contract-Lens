//
//  SummaryBox.swift
//  lawgpt
//
//  Created for displaying key takeaways at the top of AI responses
//

import SwiftUI

/// Summary box component displaying key takeaways from AI response
struct SummaryBox: View {
    let keyPoints: [String]
    
    var body: some View {
        let _ = print("✨ SummaryBox: Rendering with \(keyPoints.count) key points")
        let _ = print("   📋 Points: \(keyPoints.map { $0.prefix(40) + "..." })")
        
        return VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.legalAccent)
                    .onAppear {
                        print("   🎨 SummaryBox: Sparkles icon rendered with legal accent color")
                    }
                Text("Key Takeaways")
                    .font(DesignSystem.heading3Font())
                    .foregroundColor(.primary)
            }
            .padding(.bottom, 4)
            
            // Key points
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(keyPoints.enumerated()), id: \.offset) { index, point in
                    HStack(alignment: .top, spacing: 12) {
                        // Bullet point with accent color
                        Circle()
                            .fill(Color.legalAccent)
                            .frame(width: 6, height: 6)
                            .padding(.top, 7)
                            .onAppear {
                                if index == 0 {
                                    print("   🔵 SummaryBox: Bullet points styled with legal accent color")
                                }
                            }
                        
                        Text(point)
                            .font(DesignSystem.bodyFont())
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .onAppear {
                                if index == 0 {
                                    print("   📝 SummaryBox: Key point text rendered (length: \(point.count) chars)")
                                }
                            }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [Color.legalAccent.opacity(0.3), Color.legalAccent.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .onAppear {
            print("✅ SummaryBox: Fully rendered with gradient border and background")
        }
    }
}

#Preview {
    SummaryBox(keyPoints: [
        "Second-line ASMs have comparable efficacy (~50% seizure cessation)",
        "Continuous anesthetic infusions require ICU monitoring",
        "Early intervention improves outcomes in refractory status epilepticus"
    ])
    .padding()
}

