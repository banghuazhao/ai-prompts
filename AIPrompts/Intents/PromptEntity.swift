//
// Created by Banghua Zhao on 25/09/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import AppIntents
import SharingGRDB

/// A prompt or vibe prompt exposed to Shortcuts, Siri and Spotlight.
struct PromptEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Prompt"
    static var defaultQuery = PromptEntityQuery()

    /// Same format as `WidgetPromptItem.id`, e.g. "prompt-12" or "vibe-3".
    let id: String
    let title: String
    let text: String
    let isFavorite: Bool
    let modifiedDate: Date

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(String(text.prefix(80)))",
            image: .init(systemName: isFavorite ? "heart.fill" : "text.bubble")
        )
    }
}

extension PromptEntity {
    init(_ prompt: Prompt) {
        self.init(id: "prompt-\(prompt.id)", title: prompt.act, text: prompt.prompt, isFavorite: prompt.isFavorite, modifiedDate: prompt.modifiedDate)
    }

    init(_ vibePrompt: VibePrompt) {
        self.init(id: "vibe-\(vibePrompt.id)", title: vibePrompt.app, text: vibePrompt.prompt, isFavorite: vibePrompt.isFavorite, modifiedDate: vibePrompt.modifiedDate)
    }

    /// Every prompt in the library. The library is a few hundred rows, so filtering in memory is fine.
    static func all() throws -> [PromptEntity] {
        try AppDatabase.shared.read { db in
            try Prompt.all.fetchAll(db).map(PromptEntity.init) +
                VibePrompt.all.fetchAll(db).map(PromptEntity.init)
        }
    }
}

struct PromptEntityQuery: EntityStringQuery {
    func entities(for identifiers: [PromptEntity.ID]) async throws -> [PromptEntity] {
        let wanted = Set(identifiers)
        return try PromptEntity.all().filter { wanted.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [PromptEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return try await suggestedEntities() }
        return try PromptEntity.all()
            .filter { $0.title.localizedCaseInsensitiveContains(query) || $0.text.localizedCaseInsensitiveContains(query) }
            .sorted { lhs, rhs in
                // Title matches first.
                let lhsTitle = lhs.title.localizedCaseInsensitiveContains(query)
                let rhsTitle = rhs.title.localizedCaseInsensitiveContains(query)
                if lhsTitle != rhsTitle { return lhsTitle }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    /// Favorites first, then the most recently changed prompts.
    func suggestedEntities() async throws -> [PromptEntity] {
        let all = try PromptEntity.all()
        let favorites = all.filter(\.isFavorite).sorted { $0.modifiedDate > $1.modifiedDate }
        let recent = all.filter { !$0.isFavorite }.sorted { $0.modifiedDate > $1.modifiedDate }
        return Array((favorites + recent).prefix(30))
    }
}
