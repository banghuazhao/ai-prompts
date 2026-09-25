//
// Created by Banghua Zhao on 25/09/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import Foundation
import OSLog
import SharingGRDB
import WidgetKit

private let logger = Logger(subsystem: "AIPrompts", category: "Widgets")

/// Publishes favorites and the prompt-of-the-day pool to the widget extension.
enum WidgetSnapshotWriter {
    private static let maxFavorites = 12
    private static let maxTextLength = 400

    static func update(database: any DatabaseWriter) {
        do {
            let snapshot = try database.read { db in
                let prompts = try Prompt.all.fetchAll(db)
                let vibePrompts = try VibePrompt.all.where(\.isFavorite).fetchAll(db)

                let favoritePrompts = prompts
                    .filter(\.isFavorite)
                    .map { (date: $0.modifiedDate, item: item(for: $0)) }
                let favoriteVibePrompts = vibePrompts
                    .map { (date: $0.modifiedDate, item: item(for: $0)) }
                let favorites = (favoritePrompts + favoriteVibePrompts)
                    .sorted { $0.date > $1.date }
                    .prefix(maxFavorites)
                    .map(\.item)

                let daily = prompts
                    .sorted { $0.id < $1.id }
                    .map(item(for:))

                return WidgetSnapshot(favorites: Array(favorites), daily: daily)
            }
            if try WidgetShared.saveSnapshot(snapshot) {
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch {
            logger.error("Failed to update widget snapshot: \(error.localizedDescription)")
        }
    }

    private static func item(for prompt: Prompt) -> WidgetPromptItem {
        WidgetPromptItem(kind: .prompt, rowID: prompt.id, title: prompt.act, text: String(prompt.prompt.prefix(maxTextLength)))
    }

    private static func item(for vibePrompt: VibePrompt) -> WidgetPromptItem {
        WidgetPromptItem(kind: .vibe, rowID: vibePrompt.id, title: vibePrompt.app, text: String(vibePrompt.prompt.prefix(maxTextLength)))
    }
}
