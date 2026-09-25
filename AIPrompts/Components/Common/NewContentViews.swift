//
// Created by Banghua Zhao on 25/09/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI

/// Marks prompts delivered by a recent content update.
struct NewBadge: View {
    var body: some View {
        Text("NEW")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor, in: Capsule())
            .foregroundColor(.white)
            .accessibilityLabel(Text("New prompt"))
    }
}

/// Banner at the top of a list announcing newly added prompts.
struct NewPromptsBanner: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.shared.vibrateIfEnabled()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(count == 1 ? "1 new prompt added" : "\(count) new prompts added")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Tap to see what's new")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .glassCard(interactive: true, fallback: Color.accentColor.opacity(0.1))
        }
        .buttonStyle(.plain)
    }
}
