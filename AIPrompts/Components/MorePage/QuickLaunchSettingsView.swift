//
// Created by Banghua Zhao on 20/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import Sharing
import SwiftUI

/// Picks which assistants Quick Launch shows, their order, and the default one.
struct QuickLaunchSettingsView: View {
    @Shared(.quickLaunchOrder) private var order
    @Shared(.hiddenQuickLaunchProviders) private var hidden
    @Shared(.defaultLLMProvider) private var defaultProvider
    @AppStorage(PromptActions.copiesOnLaunchKey) private var copiesOnLaunch = true

    private var providers: [LLMProvider] {
        LLMProvider.ordered(order)
    }

    private var hiddenProviders: Set<LLMProvider> {
        LLMProvider.hidden(hidden)
    }

    var body: some View {
        List {
            Section {
                Picker("Default Assistant", selection: Binding($defaultProvider)) {
                    ForEach(LLMProvider.allCases) { provider in
                        Text(provider.label).tag(provider)
                    }
                }
            } footer: {
                Text("Long-press a prompt and choose Open in \(defaultProvider.label) to skip the detail page. The default assistant is always shown in Quick Launch.")
            }

            Section {
                ForEach(providers) { provider in
                    row(for: provider)
                }
                .onMove(perform: move)
            } header: {
                Text("Assistants")
            } footer: {
                Text("Drag to reorder. Quick Launch opens the assistant with your prompt filled in.")
            }

            Section {
                Toggle("Also Copy the Prompt", isOn: $copiesOnLaunch)
            } footer: {
                Text("Some assistants' apps open without the prompt from the link. With this on, it's also on the clipboard, ready to paste.")
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Quick Launch")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(for provider: LLMProvider) -> some View {
        let isDefault = provider == defaultProvider
        let isShown = isDefault || !hiddenProviders.contains(provider)
        return Button {
            toggle(provider)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: provider.icon)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(provider.foreground)
                    .frame(width: 30, height: 30)
                    .background(provider.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(provider.label)
                    .foregroundStyle(.primary)
                if isDefault {
                    Text("Default")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isShown ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isShown ? Color.accentColor : Color.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isShown ? .isSelected : [])
        .accessibilityHint(isDefault ? "The default assistant is always shown" : "Shows or hides this assistant in Quick Launch")
    }

    private func toggle(_ provider: LLMProvider) {
        guard provider != defaultProvider else { return }
        Haptics.shared.vibrateIfEnabled()
        var hiddenProviders = hiddenProviders
        if hiddenProviders.contains(provider) {
            hiddenProviders.remove(provider)
        } else {
            hiddenProviders.insert(provider)
        }
        $hidden.withLock { $0 = LLMProvider.store(LLMProvider.ordered(order).filter(hiddenProviders.contains)) }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var providers = providers
        providers.move(fromOffsets: source, toOffset: destination)
        $order.withLock { $0 = LLMProvider.store(providers) }
    }
}
