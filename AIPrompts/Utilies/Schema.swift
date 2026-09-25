//
// Created by Banghua Zhao on 02/06/2025
// Copyright Apps Bay Limited. All rights reserved.
//

import Foundation
import OSLog
import SharingGRDB

private let logger = Logger(subsystem: "Events", category: "Database")

/// Single database instance shared by the app UI, App Intents and widget snapshot writer.
enum AppDatabase {
    static let shared: any DatabaseWriter = {
        do {
            return try appDatabase()
        } catch {
            fatalError("Failed to open database: \(error)")
        }
    }()
}

func appDatabase() throws -> any DatabaseWriter {
    @Dependency(\.context) var context

    let database: any DatabaseWriter

    var configuration = Configuration()
    configuration.foreignKeysEnabled = true
    configuration.prepareDatabase { db in
        #if DEBUG
            db.trace(options: .profile) {
                if context == .preview {
                    print($0.expandedDescription)
                } else {
                    logger.debug("\($0.expandedDescription)")
                }
            }
        #endif
    }

    switch context {
    case .live:
        let path = URL.documentsDirectory.appending(component: "db.sqlite").path()
        logger.info("open \(path)")
        database = try DatabasePool(path: path, configuration: configuration)
    case .preview, .test:
        database = try DatabaseQueue(configuration: configuration)
    }

    var migrator = DatabaseMigrator()
    #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
    #endif
    migrator.registerMigration("Create tables") { db in
        try #sql(
            """
            CREATE TABLE "prompts" (
             "id" INTEGER PRIMARY KEY AUTOINCREMENT, 
             "act" TEXT NOT NULL DEFAULT '', 
             "prompt" TEXT NOT NULL DEFAULT '', 
             "forDevs" INTEGER NOT NULL DEFAULT 0,
             "isFavorite" INTEGER NOT NULL DEFAULT 0,
             "modifiedDate" TEXT NOT NULL DEFAULT ''
            ) STRICT 
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE TABLE "vibePrompts" ( 
             "id" INTEGER PRIMARY KEY AUTOINCREMENT, 
             "app" TEXT NOT NULL DEFAULT '',
             "prompt" TEXT NOT NULL DEFAULT '',
             "contributor" TEXT NOT NULL DEFAULT '',
             "techstack" TEXT NOT NULL DEFAULT '',
             "isFavorite" INTEGER NOT NULL DEFAULT 0,
             "modifiedDate" TEXT NOT NULL DEFAULT ''
            ) STRICT 
            """
        )
        .execute(db)
    }
    
    migrator.registerMigration("Update Prompt table to add PromptCategory") { db in
        try #sql(
            """
            CREATE TABLE "promptCategories" (
                "id" INTEGER PRIMARY KEY AUTOINCREMENT,
                "title" TEXT NOT NULL DEFAULT ''
            ) STRICT;
            """
        )
        .execute(db)
        try #sql(
            """
            ALTER TABLE "prompts" ADD COLUMN "categoryID" INTEGER REFERENCES "promptCategories"("id") ON DELETE SET NULL;
            """
        )
        .execute(db)
    }
    
    // Migrations must only touch the columns that exist at their point in history, so seed
    // with explicit columns instead of full model drafts (which gain columns over time).
    migrator.registerMigration("Seed") { db in
        let now = Date()
        for prompt in DataManager.shared.loadPromptsDraft() {
            try db.execute(
                sql: #"INSERT INTO "prompts" ("act", "prompt", "forDevs", "modifiedDate") VALUES (?, ?, ?, ?)"#,
                arguments: [prompt.act, prompt.prompt, prompt.forDevs, now]
            )
        }
        for vibePrompt in DataManager.shared.loadVibePromptsDraft() {
            try db.execute(
                sql: #"INSERT INTO "vibePrompts" ("app", "prompt", "contributor", "techstack", "modifiedDate") VALUES (?, ?, ?, ?, ?)"#,
                arguments: [vibePrompt.app, vibePrompt.prompt, vibePrompt.contributor, vibePrompt.techstack, now]
            )
        }
    }
    
    migrator.registerMigration("Seed Prompt Categories") { db in
        try db.seed {
            PromptCategoryStore.seed
        }
    }

    migrator.registerMigration("Add content sync") { db in
        try #sql(
            """
            CREATE TABLE "syncedContents" (
                "key" TEXT PRIMARY KEY NOT NULL,
                "syncedAt" TEXT NOT NULL DEFAULT ''
            ) STRICT
            """
        )
        .execute(db)
        try #sql(
            """
            ALTER TABLE "prompts" ADD COLUMN "addedDate" TEXT
            """
        )
        .execute(db)
        try #sql(
            """
            ALTER TABLE "vibePrompts" ADD COLUMN "addedDate" TEXT
            """
        )
        .execute(db)

        // Everything bundled so far was already seeded for every existing install
        // (the CSVs have not changed since v1.0.0), and anything currently in the
        // database is known too. Mark all of it as synced so prompts the user
        // deleted do not come back.
        var keys = Set<String>()
        keys.formUnion(DataManager.shared.loadPromptsDraft().map { ContentKey.prompt($0.act) })
        keys.formUnion(DataManager.shared.loadVibePromptsDraft().map { ContentKey.vibePrompt($0.app) })
        keys.formUnion(try String.fetchAll(db, sql: #"SELECT "act" FROM "prompts""#).map(ContentKey.prompt))
        keys.formUnion(try String.fetchAll(db, sql: #"SELECT "app" FROM "vibePrompts""#).map(ContentKey.vibePrompt))
        let now = Date()
        for key in keys {
            try db.execute(
                sql: #"INSERT OR IGNORE INTO "syncedContents" ("key", "syncedAt") VALUES (?, ?)"#,
                arguments: [key, now]
            )
        }
    }

    try migrator.migrate(database)
    
    try database.write { db in
        try Prompt.createTemporaryTrigger(afterUpdateTouch: \.modifiedDate)
            .execute(db)
        try VibePrompt.createTemporaryTrigger(afterUpdateTouch: \.modifiedDate)
            .execute(db)
    }

    return database
}
