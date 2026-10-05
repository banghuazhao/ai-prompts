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
