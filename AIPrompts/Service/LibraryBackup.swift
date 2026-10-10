//
// Created by Banghua Zhao on 10/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import Foundation
import SharingGRDB
import SwiftUI
import UniformTypeIdentifiers

/// A portable copy of the user's library: prompts, vibe prompts, categories and on-device chats.
///
/// Restoring merges into the current library and never deletes anything. Items are matched by
/// title (the same key content sync uses), so restoring the same backup twice changes nothing.
struct LibraryBackup: Codable {
    static let currentVersion = 1

    struct Category: Codable {
        var title: String
    }

    struct PromptItem: Codable {
        var title: String
        var prompt: String
        var forDevs: Bool?
        var isFavorite: Bool?
        var category: String?
    }

    struct VibePromptItem: Codable {
        var app: String
        var prompt: String
        var contributor: String?
        var techstack: String?
        var isFavorite: Bool?
    }

    struct Chat: Codable {
        var title: String
        var messages: [AIMessage]
        var createdDate: Date
        var modifiedDate: Date
    }

    var version: Int
    var exportedAt: Date
    var categories: [Category]?
    var prompts: [PromptItem]?
    var vibePrompts: [VibePromptItem]?
    var chats: [Chat]?

    var promptCount: Int { prompts?.count ?? 0 }
    var vibePromptCount: Int { vibePrompts?.count ?? 0 }
    var chatCount: Int { chats?.count ?? 0 }

    struct RestoreSummary: Equatable {
        var added = 0
        var updated = 0
    }

    enum BackupError: LocalizedError {
        case notABackup
        case newerVersion

        var errorDescription: String? {
            switch self {
            case .notABackup:
                String(localized: "This file isn't an AI Prompts backup.")
            case .newerVersion:
                String(localized: "This backup was made by a newer version of AI Prompts. Update the app and try again.")
            }
        }
    }

    // MARK: - Export

    static func make(database: any DatabaseReader) throws -> LibraryBackup {
        try database.read { db in
            let categories = try PromptCategory.all.order { $0.id }.fetchAll(db)
            let categoryTitles = Dictionary(categories.map { ($0.id, $0.title) }, uniquingKeysWith: { first, _ in first })
            let prompts = try Prompt.all.order { $0.id }.fetchAll(db)
            let vibePrompts = try VibePrompt.all.order { $0.id }.fetchAll(db)
            let chats = try AIChat.all.order { $0.id }.fetchAll(db)

            return LibraryBackup(
                version: currentVersion,
                exportedAt: Date(),
                categories: categories.map { Category(title: $0.title) },
                prompts: prompts.map {
                    PromptItem(
                        title: $0.act,
                        prompt: $0.prompt,
                        forDevs: $0.forDevs,
                        isFavorite: $0.isFavorite,
                        category: $0.categoryID.flatMap { categoryTitles[$0] }
                    )
                },
                vibePrompts: vibePrompts.map {
                    VibePromptItem(
                        app: $0.app,
                        prompt: $0.prompt,
                        contributor: $0.contributor,
                        techstack: $0.techstack,
                        isFavorite: $0.isFavorite
                    )
                },
                chats: chats.map {
                    Chat(title: $0.title, messages: $0.messages, createdDate: $0.createdDate, modifiedDate: $0.modifiedDate)
                }
            )
        }
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(Self.dateStyle))
        }
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> LibraryBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = try? Self.dateStyle.parse(string) {
                return date
            }
            if let date = try? Date.ISO8601FormatStyle().parse(string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
        }
        let backup: LibraryBackup
        do {
            backup = try decoder.decode(LibraryBackup.self, from: data)
        } catch {
            throw BackupError.notABackup
        }
        guard backup.version <= currentVersion else { throw BackupError.newerVersion }
        return backup
    }

    /// ISO 8601 with milliseconds, the precision the database keeps.
    private static let dateStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    static var defaultFilename: String {
        let date = Date().formatted(.iso8601.year().month().day())
        return "AI Prompts Backup \(date)"
    }

    // MARK: - Restore

    /// Merges the backup into the library in a single transaction, so a failure changes nothing.
    ///
    /// - Each backup item is paired with at most one prompt of the same title (an identical one when
    ///   there is one). A paired prompt takes the backup's text, category and developer flag, and stays
    ///   a favorite if either side marked it. Anything left unpaired is added.
    /// - Restored titles are marked as synced, so content updates won't add them a second time.
    func restore(into database: any DatabaseWriter) throws -> RestoreSummary {
        try database.write { db in
            var summary = RestoreSummary()

            // Categories, matched by exact title.
            var categoryIDs: [String: PromptCategory.ID] = [:]
            for category in try PromptCategory.all.fetchAll(db) where categoryIDs[category.title] == nil {
                categoryIDs[category.title] = category.id
            }
            for category in categories ?? [] {
                let title = category.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty, categoryIDs[title] == nil else { continue }
                let inserted = try PromptCategory.insert { PromptCategory.Draft(title: title) }
                    .returning { $0 }
                    .fetchOne(db)
                if let inserted {
                    categoryIDs[title] = inserted.id
                }
            }

            // Prompts
            var promptMatcher = RowMatcher(rows: try Prompt.all.order { $0.id }.fetchAll(db)) {
                ContentKey.prompt($0.act)
            }
            let promptItems = (prompts ?? []).compactMap { item -> (item: PromptItem, title: String, text: String)? in
                let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let text = item.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty, !text.isEmpty else { return nil }
                return (item, title, text)
            }
            let matchedPrompts = promptMatcher.match(promptItems.map { entry in
                (key: ContentKey.prompt(entry.title), isIdentical: { (row: Prompt) in Self.trimmed(row.prompt) == entry.text })
            })
            for (entry, match) in zip(promptItems, matchedPrompts) {
                let item = entry.item
                let categoryID = item.category.flatMap { categoryIDs[$0] }

                if let original = match {
                    var existing = original
                    if Self.trimmed(existing.prompt) != entry.text {
                        existing.prompt = entry.text
                    }
                    existing.forDevs = item.forDevs ?? existing.forDevs
                    existing.isFavorite = existing.isFavorite || (item.isFavorite ?? false)
                    if item.category != nil {
                        existing.categoryID = categoryID
                    }
                    // Only write real changes, so restoring doesn't reorder an unchanged library.
                    if existing != original {
                        try Prompt.update(existing).execute(db)
                        summary.updated += 1
                    }
                } else {
                    try Prompt.insert {
                        Prompt.Draft(
                            act: entry.title,
                            prompt: entry.text,
                            forDevs: item.forDevs ?? false,
                            isFavorite: item.isFavorite ?? false,
                            modifiedDate: Date(),
                            categoryID: categoryID
                        )
                    }
                    .execute(db)
                    try markSynced(ContentKey.prompt(entry.title), db: db)
                    summary.added += 1
                }
            }

            // Vibe prompts
            var vibePromptMatcher = RowMatcher(rows: try VibePrompt.all.order { $0.id }.fetchAll(db)) {
                ContentKey.vibePrompt($0.app)
            }
            let vibePromptItems = (vibePrompts ?? []).compactMap { item -> (item: VibePromptItem, app: String, text: String)? in
                let app = item.app.trimmingCharacters(in: .whitespacesAndNewlines)
                let text = item.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !app.isEmpty, !text.isEmpty else { return nil }
                return (item, app, text)
            }
            let matchedVibePrompts = vibePromptMatcher.match(vibePromptItems.map { entry in
                (key: ContentKey.vibePrompt(entry.app), isIdentical: { (row: VibePrompt) in Self.trimmed(row.prompt) == entry.text })
            })
            for (entry, match) in zip(vibePromptItems, matchedVibePrompts) {
                let item = entry.item

                if let original = match {
                    var existing = original
                    if Self.trimmed(existing.prompt) != entry.text {
                        existing.prompt = entry.text
                    }
                    existing.contributor = item.contributor ?? existing.contributor
                    existing.techstack = item.techstack ?? existing.techstack
                    existing.isFavorite = existing.isFavorite || (item.isFavorite ?? false)
                    if existing != original {
                        try VibePrompt.update(existing).execute(db)
                        summary.updated += 1
                    }
                } else {
                    try VibePrompt.insert {
                        VibePrompt.Draft(
                            app: entry.app,
                            prompt: entry.text,
                            contributor: item.contributor ?? "",
                            techstack: item.techstack ?? "",
                            isFavorite: item.isFavorite ?? false,
                            modifiedDate: Date()
                        )
                    }
                    .execute(db)
                    try markSynced(ContentKey.vibePrompt(entry.app), db: db)
                    summary.added += 1
                }
            }

            // Chats, matched by title and start time.
            var existingChats = Set(try AIChat.all.fetchAll(db).map { Self.chatKey(title: $0.title, createdDate: $0.createdDate) })
            for chat in chats ?? [] {
                let key = Self.chatKey(title: chat.title, createdDate: chat.createdDate)
                guard !chat.messages.isEmpty, !existingChats.contains(key) else { continue }
                try AIChat.insert {
                    AIChat.Draft(
                        title: chat.title,
                        messagesJSON: AIChat.encode(chat.messages),
                        createdDate: chat.createdDate,
                        modifiedDate: chat.modifiedDate
                    )
                }
                .execute(db)
                existingChats.insert(key)
                summary.added += 1
            }

            return summary
        }
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func markSynced(_ key: String, db: Database) throws {
        try db.execute(
            sql: #"INSERT OR IGNORE INTO "syncedContents" ("key", "syncedAt") VALUES (?, ?)"#,
            arguments: [key, Date()]
        )
    }

    /// Whole seconds, so tiny rounding differences between the file and the database don't matter.
    private static func chatKey(title: String, createdDate: Date) -> String {
        "\(title)|\(Int(createdDate.timeIntervalSince1970.rounded()))"
    }
}

/// Pairs backup items with library rows one-to-one, so libraries with duplicate titles restore
/// faithfully: first every item that has an identical row, then the rest with any row of the same title.
private struct RowMatcher<Row> {
    private var rowsByKey: [String: [Row]] = [:]

    init(rows: [Row], key: (Row) -> String) {
        for row in rows {
            rowsByKey[key(row), default: []].append(row)
        }
    }

    /// Returns the matched row for each item, in the same order, or nil when the item is new.
    mutating func match(_ items: [(key: String, isIdentical: (Row) -> Bool)]) -> [Row?] {
        var matches = [Row?](repeating: nil, count: items.count)
        for (index, item) in items.enumerated() {
            if let rowIndex = rowsByKey[item.key]?.firstIndex(where: item.isIdentical) {
                matches[index] = rowsByKey[item.key]?.remove(at: rowIndex)
            }
        }
        for (index, item) in items.enumerated() where matches[index] == nil {
            if let rows = rowsByKey[item.key], !rows.isEmpty {
                matches[index] = rowsByKey[item.key]?.removeFirst()
            }
        }
        return matches
    }
}

/// Wraps an encoded backup for `fileExporter`.
struct LibraryBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
