//
// Created by Banghua Zhao on 20/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI

/// Shows a rewrite from the on-device model next to the user's own text, so nothing changes
/// until they choose to use it.
struct ImprovedPromptReviewView: View {
    let proposal: PromptFormModel.ImprovementProposal
    let onUse: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !proposal.missingPlaceholders.isEmpty {
                        Label {
                            Text("The improved version leaves out these blanks: \(proposal.missingPlaceholders.formatted(.list(type: .and))). Add them back after using it, or keep your original.")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                        .font(.subheadline)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                    }

                    if !proposal.changes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What Changed")
                                .font(.headline)
                            ForEach(proposal.changes, id: \.self) { change in
                                Label(change, systemImage: "checkmark.circle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Improved Prompt")
                            .font(.headline)
                        Text(proposal.improved)
                            .font(.body)
                            .textSelection(.enabled)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AIStudioPalette.surface, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(AIStudioPalette.border))
                    }

                    DisclosureGroup("Your Original") {
                        Text(proposal.original)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    }
                    .font(.headline)
                    .tint(.primary)

                    Label("Suggested by Apple Intelligence. Check it before you use it.", systemImage: "sparkles")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .background(AIStudioPalette.canvas.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Keep Original") {
                        Haptics.shared.vibrateIfEnabled()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use This") {
                        Haptics.shared.vibrateIfEnabled()
                        onUse()
                    }
                    .font(.headline)
                    .glassButtonStyle(prominent: true)
                    .tint(AIStudioPalette.violet)
                }
            }
        }
    }
}
