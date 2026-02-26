//
//  SafetyGaugeView.swift
//  lawgpt
//
//  Arc-based safety score gauge for the ClauseGuard scanner results dashboard.
//

import SwiftUI

/// Displays an arc speedometer showing the contract safety score (0–100).
struct SafetyGaugeView: View {
    let score: Int          // 0–100
    let label: String       // e.g. "Low Risk"
    let summary: String

    @State private var animatedAngle: Double = 0

    // Gauge arc goes from -150° to +150° (300° total sweep, opens downward)
    private let startAngle: Double = -210
    private let endAngle: Double   = 30
    private var sweepAngle: Double { endAngle - startAngle } // 240°

    private var progressAngle: Double {
        startAngle + sweepAngle * (Double(score) / 100.0)
    }

    private var gaugeColor: Color {
        switch score {
        case 80...100: return Color(red: 0.15, green: 0.75, blue: 0.47)  // Green
        case 60..<80:  return Color(red: 1.0,  green: 0.75, blue: 0.0)   // Amber
        case 40..<60:  return Color(red: 1.0,  green: 0.45, blue: 0.0)   // Orange
        default:       return Color(red: 0.9,  green: 0.15, blue: 0.15)  // Red
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background track
                Circle()
                    .trim(from: 0, to: CGFloat(sweepAngle / 360.0))
                    .stroke(Color(.systemGray5), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(startAngle + 90))
                    .frame(width: 180, height: 180)

                // Coloured fill
                Circle()
                    .trim(from: 0, to: CGFloat(animatedAngle / 360.0))
                    .stroke(
                        LinearGradient(
                            colors: [gaugeColor.opacity(0.7), gaugeColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(startAngle + 90))
                    .frame(width: 180, height: 180)
                    .animation(.easeOut(duration: 1.0), value: animatedAngle)

                // Score text
                VStack(spacing: 4) {
                    Text("\(score)")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("/ 100")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 200, height: 200)

            // Risk label badge
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(gaugeColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(gaugeColor.opacity(0.12))
                .cornerRadius(20)

            // One-line summary
            Text(summary)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .lineSpacing(4)
        }
        .onAppear {
            animatedAngle = sweepAngle * (Double(score) / 100.0)
        }
        .onChange(of: score) { newScore in
            animatedAngle = sweepAngle * (Double(newScore) / 100.0)
        }
    }
}

#Preview {
    SafetyGaugeView(
        score: 42,
        label: "High Risk",
        summary: "This contract contains several clauses that heavily favour the other party."
    )
}
