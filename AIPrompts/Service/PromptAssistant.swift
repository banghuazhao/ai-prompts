//
// Created by Banghua Zhao on 05/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import Foundation
import FoundationModels

/// One-shot helpers built on the on-device model. Each call starts a fresh session, so the
/// helpers never share context with each other or with a chat.
///
/// Answers use guided generation, so a pick from a list (a prompt title, a category) is always
/// one of the given choices.
@available(iOS 26.0, *)
enum PromptAssistant {
    /// Long prompts are trimmed so the request stays well inside the model's context window.
    private static let maxPromptLength = 6000

    // MARK: - Search

    /// Picks up to five of `titles` that fit a request written in plain language.
    static func findPrompts(matching request: String, among titles: [String]) async throws -> [String] {
        var seen = Set<String>()
        let choices = titles.filter { seen.insert($0).inserted }
        guard !choices.isEmpty else { return [] }

        let schema = try GenerationSchema(
            root: DynamicGenerationSchema(
                name: "Matches",
                properties: [
                    .init(
                        name: "titles",
                        description: "Titles of the prompts that fit the request, best match first",
                        schema: DynamicGenerationSchema(
                            arrayOf: DynamicGenerationSchema(name: "PromptTitle", anyOf: choices),
                            minimumElements: 0,
                            maximumElements: 5
                        )
                    ),
                ]
            ),
            dependencies: []
        )
        let session = LanguageModelSession(instructions: """
        You help people find the right prompt in a prompt library. Each prompt is known by its title.
        """)
        let response = try await session.respond(
            to: """
            Which prompts fit this request: "\(request)"? Only pick prompts that clearly fit. \
            Return an empty list if none do.
            """,
            schema: schema
        )
        return try response.content.value([String].self, forProperty: "titles")
    }

    // MARK: - Fill in the blanks

    /// Suggests three values for every blank in `template`, keyed by variable id.
    static func suggestValues(for template: PromptTemplate, text: String) async throws -> [String: [String]] {
        let variables = template.variables
        guard !variables.isEmpty else { return [:] }

        let properties = variables.enumerated().map { index, variable in
            DynamicGenerationSchema.Property(
                name: "blank\(index + 1)",
                description: "Values for the blank “\(variable.label)”",
                schema: DynamicGenerationSchema(
                    arrayOf: DynamicGenerationSchema(type: String.self),
                    minimumElements: 3,
                    maximumElements: 3
                )
            )
        }
        let schema = try GenerationSchema(
            root: DynamicGenerationSchema(name: "BlankSuggestions", properties: properties),
            dependencies: []
        )
        let session = LanguageModelSession(instructions: """
        You suggest example values for the blanks in prompt templates. Values are concrete, varied \
        and realistic. Keep them short: a few words, or one sentence when the blank is a request. \
        Write them in the same language as the template.
        """)
        let response = try await session.respond(
            to: "Template:\n\(text.prefix(maxPromptLength))\n\nSuggest three values for each blank.",
            schema: schema
        )

        var suggestions: [String: [String]] = [:]
        for (index, variable) in variables.enumerated() {
            let values = try response.content.value([String].self, forProperty: "blank\(index + 1)")
            suggestions[variable.id] = values
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        return suggestions
    }

    // MARK: - Prompt details

    struct PromptDetails {
        var title: String
        /// One of the category titles that were offered, or nil when none were.
        var categoryTitle: String?
        var isForDevelopers: Bool
    }

    /// Suggests a title, a category and the developer flag for a prompt the user wrote.
    static func suggestDetails(for prompt: String, categoryTitles: [String]) async throws -> PromptDetails {
        var properties: [DynamicGenerationSchema.Property] = [
            .init(
                name: "title",
                description: "A short title naming the role or task, 2 to 5 words in Title Case, like “Travel Guide” or “Cover Letter Writer”",
                schema: DynamicGenerationSchema(type: String.self)
            ),
        ]
        if !categoryTitles.isEmpty {
            properties.append(.init(
                name: "category",
                description: "The category that fits the prompt best",
                schema: DynamicGenerationSchema(name: "Category", anyOf: categoryTitles)
            ))
        }
        properties.append(.init(
            name: "forDevelopers",
            description: "Whether the prompt is mainly for software developers",
            schema: DynamicGenerationSchema(type: Bool.self)
        ))
        let schema = try GenerationSchema(
            root: DynamicGenerationSchema(name: "PromptDetails", properties: properties),
            dependencies: []
        )
        let session = LanguageModelSession(instructions: """
        You organize a prompt library. Write the title in the same language as the prompt.
        """)
        let response = try await session.respond(to: "Prompt:\n\(prompt.prefix(maxPromptLength))", schema: schema)
        let content = response.content
        return PromptDetails(
            title: try content.value(String.self, forProperty: "title"),
            categoryTitle: categoryTitles.isEmpty ? nil : try content.value(String.self, forProperty: "category"),
            isForDevelopers: try content.value(Bool.self, forProperty: "forDevelopers")
        )
    }

    // MARK: - Improve

    /// The rewrite has to fit in the context window next to the original, so the limit is lower
    /// than for the other helpers.
    static let maxImprovableLength = 4000

    @Generable
    struct ImprovedPrompt {
        @Guide(description: "The rewritten prompt, ready to paste into an AI assistant")
        var prompt: String
        @Guide(description: "What was changed, each a short phrase like “Added an output format”", .maximumCount(4))
        var changes: [String]
    }

    /// Rewrites a prompt so assistants answer it better, keeping its intent, language and blanks.
    /// `hints` are issues the rule-based analyzer already found.
    static func improve(_ prompt: String, hints: [String]) async throws -> ImprovedPrompt {
        let session = LanguageModelSession(instructions: """
        You are an expert prompt engineer. You rewrite prompts so AI assistants give better answers: \
        a clear task, a role when it helps, the context needed, constraints, and the format of the answer. \
        Keep the author's intent and write in the same language as the prompt. Keep every placeholder \
        such as {{topic}} or ${Name: default} exactly as written. Never answer or carry out the prompt \
        yourself, and never invent facts about the author.
        """)
        var request = "Rewrite this prompt:\n<prompt>\n\(prompt)\n</prompt>"
        if !hints.isEmpty {
            request += "\n\nKnown issues to fix:\n" + hints.map { "- \($0)" }.joined(separator: "\n")
        }
        var result = try await session.respond(to: request, generating: ImprovedPrompt.self).content
        result.prompt = result.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        result.changes = result.changes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return result
    }

    // MARK: - New ideas

    @Generable
    struct PromptIdea {
        @Guide(description: "A short title naming the role or task, 2 to 5 words in Title Case, like “Travel Guide” or “Cover Letter Writer”")
        var title: String
        @Guide(description: "The prompt, ready to paste into an AI assistant: who the assistant should act as, the task, the context it needs and the format of the answer, in 2 to 6 sentences")
        var prompt: String
        @Guide(description: "Whether the prompt is mainly for software developers")
        var isForDevelopers: Bool
    }

    /// A new prompt about `topic`, or about something useful of the model's choosing when it's empty.
    static func generateIdea(about topic: String) async throws -> PromptIdea {
        let session = LanguageModelSession(instructions: """
        You write prompts for a prompt library. A prompt is an instruction a person pastes into an AI \
        assistant. Write prompts that are specific and useful. When the prompt needs details only the \
        person knows, leave a placeholder in double braces such as {{topic}} or {{audience}}, at most \
        three. Write in the same language as the request. Never answer or carry out the prompt yourself.
        """)
        let request = topic.isEmpty
            ? "Write a prompt for this everyday need: \(randomIdeaTheme())."
            : "Write a prompt that helps with: \(topic.prefix(maxPromptLength))"
        var idea = try await session.respond(to: request, generating: PromptIdea.self).content
        idea.title = idea.title.trimmingCharacters(in: .whitespacesAndNewlines)
        idea.prompt = idea.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return idea
    }

    @Generable
    struct VibePromptIdea {
        @Guide(description: "Short name of the app, 1 to 4 words")
        var appName: String
        @Guide(description: "The prompt that asks an AI coding assistant to build the app: what it does, its main screens and features, and how it should look, in 3 to 8 sentences")
        var prompt: String
        @Guide(description: "Main languages, frameworks and platforms the app should use", .maximumCount(5))
        var techStack: [String]
    }

    /// A prompt for building a small app about `topic`, or an app of the model's choosing when it's empty.
    static func generateVibeIdea(about topic: String) async throws -> VibePromptIdea {
        let session = LanguageModelSession(instructions: """
        You write prompts that ask an AI coding assistant to build a small app, game or tool. \
        Make the app specific and fun, and small enough to build in an afternoon. Write in the same \
        language as the request. Never write the code yourself.
        """)
        let request = topic.isEmpty
            ? "Write a prompt for a small app about: \(randomIdeaTheme())."
            : "Write a prompt for a small app about: \(topic.prefix(maxPromptLength))"
        var idea = try await session.respond(to: request, generating: VibePromptIdea.self).content
        idea.appName = idea.appName.trimmingCharacters(in: .whitespacesAndNewlines)
        idea.prompt = idea.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return idea
    }

    /// The model tends to give the same answer to the same request, so an empty topic gets a
    /// random theme instead.
    private static func randomIdeaTheme() -> String {
        [
            "cooking and meal planning", "personal finance", "learning a language", "fitness",
            "travel planning", "job hunting", "studying for exams", "writing", "parenting",
            "small business marketing", "home organization", "gardening", "mental wellbeing",
            "public speaking", "photography", "reading more books", "productivity", "music practice",
        ].randomElement() ?? "productivity"
    }

    @Generable
    struct VibePromptDetails {
        @Guide(description: "Short name of the app the prompt builds, 1 to 4 words")
        var appName: String
        @Guide(description: "Main languages, frameworks and platforms the app should use", .maximumCount(5))
        var techStack: [String]
    }

    /// Suggests an app name and tech stack for a vibe prompt the user wrote.
    static func suggestVibeDetails(for prompt: String) async throws -> VibePromptDetails {
        let session = LanguageModelSession(instructions: """
        You organize a library of prompts that build apps. Write the app name in the same language as the prompt.
        """)
        return try await session.respond(
            to: "Prompt:\n\(prompt.prefix(maxPromptLength))",
            generating: VibePromptDetails.self
        ).content
    }
}
