//
// Created by Banghua Zhao on 02/06/2025
// Copyright Apps Bay Limited. All rights reserved.
//

import Foundation
import OSLog
import SharingGRDB

private let logger = Logger(subsystem: "Events", category: "Database")

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
             "isFavorite" INTEGER NOT NULL DEFAULT 0
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
             "isFavorite" INTEGER NOT NULL DEFAULT 0
            ) STRICT 
            """
        )
        .execute(db)
    }
    
    migrator.registerMigration("Seed") { db in
        try db.seed {
            DataManager.shared.loadPromptsDraft()
            DataManager.shared.loadVibePromptsDraft()
        }
    }

    try migrator.migrate(database)

    return database
}
