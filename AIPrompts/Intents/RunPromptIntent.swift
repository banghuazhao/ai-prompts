//
// Created by Banghua Zhao on 05/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import AppIntents
import FoundationModels
import SharingGRDB
import SwiftUI

/// Runs a prompt with the on-device model from Siri, Shortcuts or Spotlight, without opening the app.
@available(iOS 26.0, *)
struct RunPromptIntent: AppIntent {
    static var title: LocalizedStringResource = "Run Prompt with Apple Intelligence"
    static var description = IntentDescription("Runs a prompt with the on-device model and returns the answer. Free, private and works offline.")

    @Parameter(title: "Prompt")
    var prompt: PromptEntity

    @Parameter(
        title: "Input",
        description: "Optional text for the prompt to work on, such as your request or a document.",
        inputOptions: String.IntentInputOptions(multiline: true)
    )
    var input: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Run \(\.$prompt)") {
            \.$input
        }
    }

    init() {}

    init(prompt: PromptEntity) {
        self.prompt = prompt
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog & ShowsSnippetView {
        switch OnDeviceAI.status {
        case .available:
            break
        case .notEnabled:
            throw RunPromptError(String(localized: "Turn on Apple Intelligence in Settings › Apple Intelligence & Siri to run prompts for free, right on your iPhone."))
        case .notReady:
            throw RunPromptError(String(localized: "Apple Intelligence is still downloading. Try again once it's ready."))
        case .unsupportedLanguage:
            throw RunPromptError(String(localized: "Apple Intelligence doesn't support your current language yet."))
        case .unsupported:
            throw RunPromptError(String(localized: "Running prompts on device needs an iPhone that supports Apple Intelligence."))
        }

        let text = Self.promptText(prompt.text, input: input)
        let session = LanguageModelSession(instructions: """
        You are a helpful assistant. The user's message is a prompt from a prompt library: follow it \
        as written. Keep the answer concise, because it's shown in Siri and Shortcuts. Reply in the \
        same language as the user's message.
        """)
        let answer: String
        do {
            answer = try await session.respond(to: text).content
        } catch {
            throw RunPromptError(OnDeviceAIFailure(error).message)
        }

        saveToChats(prompt: text, answer: answer)
        PromptActions.ranOnDevice()
        return .result(
            value: answer,
            dialog: "Here's the answer for “\(prompt.title)”.",
            view: PromptAnswerSnippet(title: prompt.title, answer: answer)
        )
    }

    /// Puts `input` into the prompt's first blank (preferring a "My first request is …" example),
    /// or appends it when the prompt has no blanks.
    static func promptText(_ prompt: String, input: String?) -> String {
        let template = PromptTemplate(prompt)
        var values = PromptVariableMemory.initialValues(for: template)
        let input = input?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !input.isEmpty else {
            return template.render(values)
        }
        let target = template.variables.first { $0.id.hasPrefix("first ") } ?? template.variables.first
        guard let target else {
            return "\(prompt)\n\n\(input)"
        }
        values[target.id] = input
        return template.render(values)
    }

    /// Runs from Siri show up in Favorites › Chats like runs from inside the app.
    private func saveToChats(prompt text: String, answer: String) {
        let messages = [AIMessage(role: .user, text: text), AIMessage(role: .assistant, text: answer)]
        withErrorReporting {
            try AppDatabase.shared.write { db in
                try AIChat.insert {
                    AIChat.Draft(title: prompt.title, messagesJSON: AIChat.encode(messages))
                }
                .execute(db)
            }
        }
    }
}

struct RunPromptError: Error, CustomLocalizedStringResourceConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var localizedStringResource: LocalizedStringResource {
        "\(message)"
    }
}

private struct PromptAnswerSnippet: View {
    let title: String
    let answer: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(.purple)
            Text(answer)
                .font(.callout)
                .lineLimit(20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}
