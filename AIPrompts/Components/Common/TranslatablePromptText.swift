//
// Created by Banghua Zhao on 05/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import NaturalLanguage
import SwiftUI
import Translation

/// Prompt text with an on-device Translate toggle, offered when the prompt isn't written
/// in the user's language (iOS 18+).
struct TranslatablePromptText: View {
    let text: String

    @State private var translation: String?
    @State private var showsTranslation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(showsTranslation ? translation ?? text : text)
                .font(.body)
                .lineSpacing(5)
                .foregroundColor(.primary)
                .textSelection(.enabled)
            if #available(iOS 18.0, *), Self.needsTranslation(text) {
                TranslationControls(
                    text: text,
                    translation: $translation,
                    showsTranslation: $showsTranslation
                )
            }
        }
        .onChange(of: text) { _, _ in
            translation = nil
            showsTranslation = false
        }
    }

    /// The language the user reads, which may differ from the app's localization.
    static var userLanguage: Locale.Language {
        Locale.Language(identifier: Locale.preferredLanguages.first ?? "en")
    }

    static func needsTranslation(_ text: String) -> Bool {
        guard let source = NLLanguageRecognizer.dominantLanguage(for: text) else { return false }
        return Locale.Language(identifier: source.rawValue).languageCode != userLanguage.languageCode
    }
}

@available(iOS 18.0, *)
private struct TranslationControls: View {
    let text: String
    @Binding var translation: String?
    @Binding var showsTranslation: Bool

    @State private var configuration: TranslationSession.Configuration?
    @State private var isTranslating = false
    @State private var failed = false
    @State private var copied = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.shared.vibrateIfEnabled()
                onToggle()
            } label: {
                HStack(spacing: 6) {
                    if isTranslating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "translate")
                    }
                    Text(showsTranslation ? "Show Original" : "Translate")
                }
                .font(.subheadline)
            }
            .glassButtonStyle()
            .disabled(isTranslating)

            if showsTranslation, let translation {
                Button {
                    Haptics.shared.vibrateIfEnabled()
                    PromptActions.copy(translation)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                } label: {
                    Label(copied ? "Copied!" : "Copy Translation", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.subheadline)
                }
                .buttonStyle(.borderless)
            }
        }
        .translationTask(configuration) { session in
            do {
                let response = try await session.translate(text)
                translation = response.targetText
                withAnimation {
                    showsTranslation = true
                }
            } catch {
                failed = true
            }
            isTranslating = false
        }

        if failed {
            Text("Couldn't translate this prompt. Try again later.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func onToggle() {
        if translation != nil {
            withAnimation {
                showsTranslation.toggle()
            }
            return
        }
        failed = false
        isTranslating = true
        if configuration == nil {
            configuration = TranslationSession.Configuration(target: TranslatablePromptText.userLanguage)
        } else {
            configuration?.invalidate()
        }
    }
}
