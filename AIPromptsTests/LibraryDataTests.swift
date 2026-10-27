//
// Created by Banghua Zhao on 27/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

@testable import AIPrompts
import Foundation
import Testing

// Each test opens its own in-memory database, seeded with the bundled library like a fresh install.

/// An in-memory library. Helpers keep GRDB type names out of the tests, since the test target
/// doesn't import the database packages itself.
private struct TestLibrary {
    let database = try! appDatabase()

    func prompts(titled title: String) throws -> [Prompt] {
        try database.read { db in
            try Prompt.where { $0.act.eq(title) }.fetchAll(db)
        }
    }

    func vibePrompts(titled app: String) throws -> [VibePrompt] {
        try database.read { db in
            try VibePrompt.where { $0.app.eq(app) }.fetchAll(db)
        }
    }

    func category(titled title: String) throws -> PromptCategory? {
        try database.read { db in
            try PromptCategory.where { $0.title.eq(title) }.fetchOne(db)
        }
    }
}

struct ContentSyncTests {
    @Test func bundledPromptsAreAlreadyKnownAfterSeeding() throws {
        let library = TestLibrary()
        let bundled = DataManager.shared.loadPromptsDraft().map {
            ContentSync.CuratedPrompt(title: $0.act, prompt: $0.prompt, forDevs: $0.forDevs)
        }
        #expect(!bundled.isEmpty)
        #expect(try ContentSync.apply(prompts: bundled, vibePrompts: [], database: library.database) == 0)
    }

    @Test func newPromptsAreAddedOnceWithTheirCategory() throws {
        let library = TestLibrary()
        let item = ContentSync.CuratedPrompt(title: "Test Sync Prompt", prompt: "Do the test.", category: "productivity")
        #expect(try ContentSync.apply(prompts: [item], vibePrompts: [], database: library.database) == 1)
        #expect(try ContentSync.apply(prompts: [item], vibePrompts: [], database: library.database) == 0)

        let rows = try library.prompts(titled: "Test Sync Prompt")
        #expect(rows.count == 1)
        #expect(rows.first?.isNew == true)
        let productivity = try library.category(titled: "💼 Productivity")
        #expect(productivity != nil)
        #expect(rows.first?.categoryID == productivity?.id)
    }

    @Test func deletedPromptsDontComeBack() throws {
        let library = TestLibrary()
        let item = ContentSync.CuratedPrompt(title: "Test Deleted Prompt", prompt: "Gone for good.")
        _ = try ContentSync.apply(prompts: [item], vibePrompts: [], database: library.database)
        try library.database.write { db in
            try Prompt.where { $0.act.eq("Test Deleted Prompt") }.delete().execute(db)
        }
        #expect(try ContentSync.apply(prompts: [item], vibePrompts: [], database: library.database) == 0)
        #expect(try library.prompts(titled: "Test Deleted Prompt").isEmpty)
    }

    @Test func feedItemsAreTrimmedAndDated() throws {
        let json = """
        {
          "version": 1,
          "prompts": [
            { "title": "  Weekly Coach ", "prompt": " Plan my week. ", "category": "💼 Productivity", "addedAt": "2026-09-25" },
            { "title": "Undated", "prompt": "Text", "addedAt": "not a date" }
          ],
          "vibePrompts": [
            { "app": "Timer", "prompt": "Build a timer.", "techstack": "SwiftUI" }
          ]
        }
        """
        let feed = try JSONDecoder().decode(ContentSync.Feed.self, from: Data(json.utf8))
        let prompts = feed.curatedPrompts
        #expect(prompts.map(\.title) == ["Weekly Coach", "Undated"])
        #expect(prompts.first?.prompt == "Plan my week.")
        #expect(prompts.first?.addedAt != nil)
        #expect(prompts.last?.addedAt == nil)
        #expect(feed.curatedVibePrompts.first?.contributor == "")
        #expect(feed.curatedVibePrompts.first?.techstack == "SwiftUI")
    }
}

struct LibraryBackupTests {
    private static let chatDate = Date(timeIntervalSince1970: 1_800_000_000)

    private func backup(promptText: String = "Backup text", isFavorite: Bool = true) -> LibraryBackup {
        LibraryBackup(
            version: LibraryBackup.currentVersion,
            exportedAt: Self.chatDate,
            categories: [.init(title: "Test Category")],
            prompts: [.init(title: "Backup Prompt", prompt: promptText, forDevs: true, isFavorite: isFavorite, category: "Test Category")],
            vibePrompts: [.init(app: "Backup App", prompt: "Build it.", contributor: nil, techstack: "SwiftUI", isFavorite: nil)],
            chats: [.init(title: "Backup Chat", messages: [AIMessage(role: .user, text: "Hi")], createdDate: Self.chatDate, modifiedDate: Self.chatDate)]
        )
    }

    @Test func restoringTwiceChangesNothingTheSecondTime() throws {
        let library = TestLibrary()
        #expect(try backup().restore(into: library.database) == LibraryBackup.RestoreSummary(added: 3, updated: 0))
        #expect(try backup().restore(into: library.database) == LibraryBackup.RestoreSummary(added: 0, updated: 0))

        let restored = try library.prompts(titled: "Backup Prompt")
        #expect(restored.count == 1)
        #expect(restored.first?.isFavorite == true)
        #expect(restored.first?.forDevs == true)
        #expect(restored.first?.categoryID == (try library.category(titled: "Test Category"))?.id)
        #expect(try library.vibePrompts(titled: "Backup App").first?.techstack == "SwiftUI")
    }

    @Test func restoreUpdatesTextAndKeepsFavorites() throws {
        let library = TestLibrary()
        _ = try backup().restore(into: library.database)
        let summary = try backup(promptText: "New text", isFavorite: false).restore(into: library.database)
        #expect(summary == LibraryBackup.RestoreSummary(added: 0, updated: 1))
        let restored = try library.prompts(titled: "Backup Prompt")
        #expect(restored.map(\.prompt) == ["New text"])
        #expect(restored.first?.isFavorite == true)
    }

    @Test func encodedBackupDecodes() throws {
        let decoded = try LibraryBackup.decode(backup().encoded())
        #expect(decoded.promptCount == 1)
        #expect(decoded.vibePromptCount == 1)
        #expect(decoded.chatCount == 1)
        #expect(decoded.exportedAt == Self.chatDate)
        #expect(decoded.chats?.first?.messages.first?.text == "Hi")
    }

    @Test func otherFilesAreRejected() {
        #expect(throws: LibraryBackup.BackupError.notABackup) {
            try LibraryBackup.decode(Data("{}".utf8))
        }
        #expect(throws: LibraryBackup.BackupError.newerVersion) {
            try LibraryBackup.decode(Data(#"{"version": 99, "exportedAt": "2026-10-27T00:00:00.000Z"}"#.utf8))
        }
    }
}

@MainActor
struct PromptTrashTests {
    @Test func undoPutsBackThePromptAndItsUsage() throws {
        let library = TestLibrary()
        let prompt = try #require(try library.database.read { db in
            try Prompt.all.order { $0.id }.fetchOne(db)
        })
        try library.database.write { db in
            try db.execute(
                sql: #"INSERT INTO "promptUsages" ("promptID", "lastUsedDate", "useCount") VALUES (?, ?, ?)"#,
                arguments: [prompt.id, Date(), 3]
            )
        }

        PromptTrash.delete([prompt], in: library.database)
        #expect(try library.prompts(titled: prompt.act).allSatisfy { $0.id != prompt.id })
        #expect(UndoCenter.shared.notice?.canUndo == true)

        UndoCenter.shared.undo()
        #expect(UndoCenter.shared.notice == nil)
        let restored = try library.prompts(titled: prompt.act).first { $0.id == prompt.id }
        #expect(restored?.prompt == prompt.prompt)
        #expect(restored?.isFavorite == prompt.isFavorite)
        let usage = try library.database.read { db in
            try PromptUsage.where { $0.promptID.eq(prompt.id) }.fetchOne(db)
        }
        #expect(usage?.useCount == 3)
    }
}
