//
// Created by Banghua Zhao on 10/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI

/// Horizontal shelf of the prompts the user copied, launched or ran most recently.
struct RecentlyUsedShelf: View {
    let prompts: [Prompt]
    let onSelect: (Prompt) -> Void
    /// Shows the Customize sheet, for "Open in …" while a blank still needs a value.
    let onCustomize: (Prompt) -> Void
    let onRemove: (Prompt) -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Recently Used", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                Spacer()
                Button("Clear") {
                    Haptics.shared.vibrateIfEnabled()
                    onClear()
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderless)
                .accessibilityLabel("Clear recently used prompts")
            }
            .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(prompts) { prompt in
                        // Buttons rather than NavigationLinks: several links in one List row all fire together.
                        Button {
                            Haptics.shared.vibrateIfEnabled()
                            onSelect(prompt)
                        } label: {
                            RecentPromptCard(prompt: prompt)
                        }
                        .buttonStyle(.borderless)
                        .contextMenu {
                            Button {
                                Haptics.shared.vibrateIfEnabled()
                                PromptActions.copy(prompt.prompt)
                                PromptUsage.record(promptID: prompt.id)
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            OpenInDefaultLLMButton(prompt: prompt.prompt, onNeedsBlanks: { onCustomize(prompt) }) {
                                PromptUsage.record(promptID: prompt.id)
                            }
                            Button {
                                Haptics.shared.vibrateIfEnabled()
                                onRemove(prompt)
                            } label: {
                                Label("Remove from Recently Used", systemImage: "minus.circle")
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }
}

private struct RecentPromptCard: View {
    let prompt: Prompt

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: prompt.forDevs ? "chevron.left.forwardslash.chevron.right" : "text.quote")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AIStudioPalette.violet)
                .accessibilityHidden(true)
            Text(prompt.act)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 156, alignment: .topLeading)
        .frame(minHeight: 92, alignment: .topLeading)
        .background(AIStudioPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(AIStudioPalette.border, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
