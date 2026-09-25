//
// Created by Banghua Zhao on 25/09/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import AppIntents
import UIKit

struct CopyPromptIntent: AppIntent {
    static var title: LocalizedStringResource = "Copy Prompt"
    static var description = IntentDescription("Copies a prompt to the clipboard so you can paste it into any AI chat.")

    @Parameter(title: "Prompt")
    var prompt: PromptEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Copy \(\.$prompt)")
    }

    init() {}

    init(prompt: PromptEntity) {
        self.prompt = prompt
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        PromptActions.copy(prompt.text)
        return .result(value: prompt.text, dialog: "Copied “\(prompt.title)”. Paste it into your AI chat.")
    }
}

struct OpenPromptIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Prompt"
    static var description = IntentDescription("Opens a prompt in AI Prompts.")
    static var openAppWhenRun = true

    @Parameter(title: "Prompt")
    var prompt: PromptEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$prompt)")
    }

    init() {}

    init(prompt: PromptEntity) {
        self.prompt = prompt
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        DeepLinkRouter.shared.open(id: prompt.id)
        return .result()
    }
}

struct RandomPromptIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Random Prompt"
    static var description = IntentDescription("Picks a random prompt for inspiration and copies it to the clipboard.")

    @Parameter(title: "Favorites Only", default: false)
    var favoritesOnly: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Get a random prompt") {
            \.$favoritesOnly
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<PromptEntity> & ProvidesDialog {
        let candidates = try PromptEntity.all().filter { !favoritesOnly || $0.isFavorite }
        guard let prompt = candidates.randomElement() else {
            throw $favoritesOnly.needsValueError("You have no favorite prompts yet. Try all prompts instead?")
        }
        PromptActions.copy(prompt.text)
        return .result(value: prompt, dialog: "“\(prompt.title)” is copied and ready to paste.")
    }
}

struct AIPromptsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CopyPromptIntent(),
            phrases: [
                "Copy a prompt from \(.applicationName)",
                "Copy \(\.$prompt) from \(.applicationName)",
            ],
            shortTitle: "Copy Prompt",
            systemImageName: "doc.on.doc"
        )
        AppShortcut(
            intent: OpenPromptIntent(),
            phrases: [
                "Open a prompt in \(.applicationName)",
                "Open \(\.$prompt) in \(.applicationName)",
            ],
            shortTitle: "Open Prompt",
            systemImageName: "text.bubble"
        )
        AppShortcut(
            intent: RandomPromptIntent(),
            phrases: [
                "Give me a random prompt from \(.applicationName)",
                "Inspire me with \(.applicationName)",
            ],
            shortTitle: "Random Prompt",
            systemImageName: "shuffle"
        )
    }
}
