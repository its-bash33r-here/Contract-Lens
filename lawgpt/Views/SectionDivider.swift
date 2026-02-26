//
//  SectionDivider.swift
//  lawgpt
//
//  Created for visual separation between major content sections
//

import SwiftUI

/// Visual divider between major content sections
struct SectionDivider: View {
    var body: some View {
        let _ = print("➖ SectionDivider: Rendering divider")
        let _ = print("   📏 Vertical padding: \(DesignSystem.sectionDividerSpacing / 2)px")
        
        return HStack(spacing: 12) {
            // Subtle gradient line
            LinearGradient(
                colors: [
                    Color.clear,
                    Color(.separator).opacity(0.5),
                    Color(.separator).opacity(0.3),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1)
            .onAppear {
                print("   🎨 SectionDivider: Gradient line rendered")
            }
        }
        .padding(.vertical, DesignSystem.sectionDividerSpacing / 2)
        .onAppear {
            print("✅ SectionDivider: Fully rendered")
        }
    }
}

#Preview {
    VStack {
        Text("Section 1")
            .font(.title)
        SectionDivider()
        Text("Section 2")
            .font(.title)
    }
    .padding()
}

