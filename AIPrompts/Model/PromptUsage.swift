//
// Created by Banghua Zhao on 10/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import Foundation
import OSLog
import SharingGRDB

private let logger = Logger(subsystem: "AIPrompts", category: "PromptUsage")

/// How often and how recently a prompt was used (copied, quick launched or run on device).
///
/// Kept in its own table rather than on `prompts`, so recording a use never bumps the prompt's
/// `modifiedDate` (which orders the lists) and whole-row prompt updates never overwrite it.
@Table
struct PromptUsage: Identifiable, Hashable {
    let id: Int
    var promptID: Prompt.ID
    var lastUsedDate: Date = Date()
    var useCount: Int = 0
}

extension PromptUsage {
    /// Number of prompts shown in the Recently Used shelf.
    static let recentLimit = 10

    /// Records one use of a prompt. Failing to record is never worth interrupting the user for.
    static func record(promptID: Prompt.ID) {
        @Dependency(\.defaultDatabase) var database
        do {
            try database.write { db in
                try db.execute(
                    sql: """
                    INSERT INTO "promptUsages" ("promptID", "lastUsedDate", "useCount")
                    SELECT "id", ?, 1 FROM "prompts" WHERE "id" = ?
                    ON CONFLICT("promptID") DO UPDATE SET
                        "lastUsedDate" = excluded."lastUsedDate",
                        "useCount" = "useCount" + 1
                    """,
                    arguments: [Date(), promptID]
                )
            }
        } catch {
            logger.error("Failed to record prompt use: \(error.localizedDescription)")
        }
    }

    /// Records a use from an App Intent, whose entity ids look like "prompt-12" or "vibe-3".
    static func record(entityID: String) {
        if entityID.hasPrefix("prompt-"), let id = Int(entityID.dropFirst("prompt-".count)) {
            record(promptID: id)
        } else if entityID.hasPrefix("vibe-"), let id = Int(entityID.dropFirst("vibe-".count)) {
            VibePromptUsage.record(vibePromptID: id)
        }
    }

    static func remove(promptID: Prompt.ID) {
        @Dependency(\.defaultDatabase) var database
        withErrorReporting {
            try database.write { db in
                try PromptUsage.where { $0.promptID.eq(promptID) }.delete().execute(db)
            }
        }
    }

    static func removeAll() {
        @Dependency(\.defaultDatabase) var database
        withErrorReporting {
            try database.write { db in
                try PromptUsage.delete().execute(db)
            }
        }
    }
}
