//
//  SkeletonView.swift
//  lawgpt
//
//  Created by Bash33r on 03/12/25.
//

import SwiftUI

struct SkeletonLoadingView: View {
    let statusText: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Status text
            HStack {
                // Left aligned status text
                Text(statusText)
                    .font(DesignSystem.secondaryBodyFont())
                    .foregroundStyle(DesignSystem.highlightColor) // Legal Blue
                    .transition(.opacity) // Smooth transition for text changes
                    .id(statusText) // Force animation on change
                
                Spacer()
                
                // Optional: Keep spinner or remove if "shimmer" is enough
                // Leaving spinner but pushing it right ensures text is left
            }
            .padding(.bottom, 8)
            
            // Skeleton lines - naturally left aligned in VStack
            VStack(alignment: .leading, spacing: 12) {
                skeletonLine(width: 200, height: 24) // Heading
                
                VStack(alignment: .leading, spacing: 8) { // Ensure inner VStacks are leading aligned
                    skeletonLine(width: .infinity, height: 16)
                    skeletonLine(width: .infinity, height: 16)
                    skeletonLine(width: 280, height: 16)
                }
                .padding(.top, 8)
                
                VStack(alignment: .leading, spacing: 8) {
                    skeletonLine(width: .infinity, height: 16)
                    skeletonLine(width: .infinity, height: 16)
                    skeletonLine(width: 150, height: 16)
                }
                .padding(.top, 8)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading) // Force container to leading alignment
    }
    
    private func skeletonLine(width: CGFloat?, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color(.systemGray5))
            .frame(height: height)
            .frame(maxWidth: width == .infinity ? .infinity : width)
            .shimmer(
                accentColor: DesignSystem.highlightColor,
                backgroundColor: Color(.systemGray5)
            )
    }
}
