//
//  AppLogoGradientView.swift
//  lawgpt
//
//  Created by Cursor on 27/01/26.
//

import SwiftUI

/// Reusable branded logo with a soft gradient background.
/// Used anywhere `Image("AppLogo")` appears to keep styling consistent.
struct AppLogoGradientView: View {
    /// Overall square size of the logo block.
    var size: CGFloat
    /// Corner radius for the background container.
    var cornerRadius: CGFloat = 28
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black,
                            Color.black
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.55), radius: 24, x: 0, y: 14)
                .shadow(color: DesignSystem.highlightColor.opacity(0.4), radius: 18, x: 0, y: 4)
            
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                // Padding keeps the gold logo inside the gradient frame
                .padding(size * 0.18)
        }
        .frame(width: size, height: size)
    }
}

