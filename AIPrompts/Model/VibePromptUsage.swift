//
// Created by Banghua Zhao on 16/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import Foundation
import OSLog
import SharingGRDB

private let logger = Logger(subsystem: "AIPrompts", category: "VibePromptUsage")

/// How often and how recently a vibe prompt was used (copied, quick launched or run on device).
///
/// The vibe prompt counterpart of `PromptUsage`, kept in its own table for the same reasons.
@Table
struct VibePromptUsage: Identifiable, Hashable {
    let id: Int
    var vibePromptID: VibePrompt.ID
    var lastUsedDate: Date = Date()
    var useCount: Int = 0
}

extension VibePromptUsage {
    /// Records one use of a vibe prompt. Failing to record is never worth interrupting the user for.
    static func record(vibePromptID: VibePrompt.ID) {
        @Dependency(\.defaultDatabase) var database
        do {
            try database.write { db in
                try db.execute(
                    sql: """
                    INSERT INTO "vibePromptUsages" ("vibePromptID", "lastUsedDate", "useCount")
                    SELECT "id", ?, 1 FROM "vibePrompts" WHERE "id" = ?
                    ON CONFLICT("vibePromptID") DO UPDATE SET
                        "lastUsedDate" = excluded."lastUsedDate",
                        "useCount" = "useCount" + 1
                    """,
                    arguments: [Date(), vibePromptID]
                )
            }
        } catch {
            logger.error("Failed to record vibe prompt use: \(error.localizedDescription)")
        }
    }
}
