//
// Created by Banghua Zhao on 27/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import Foundation
import OSLog
import SharingGRDB

private let logger = Logger(subsystem: "AIPrompts", category: "SharedInbox")

/// Adds prompts saved from the share sheet to the library when the app comes to the front.
@MainActor
enum SharedInboxImporter {
    /// Titles made from the start of the prompt are cut to this many characters.
    static let derivedTitleLength = 40

    static func importPending(database: any DatabaseWriter) {
        let pending = SharedInbox.takeAll()
        guard !pending.isEmpty else { return }
        do {
            try database.write { db in
                let now = Date()
                for item in pending {
                    try db.execute(
                        sql: #"INSERT INTO "prompts" ("act", "prompt", "modifiedDate") VALUES (?, ?, ?)"#,
                        arguments: [title(for: item), item.prompt, now]
                    )
                }
            }
        } catch {
            logger.error("Failed to add shared prompts: \(error.localizedDescription)")
            // Keep them for the next try rather than losing what the user shared.
            for item in pending {
                try? SharedInbox.append(item)
            }
            return
        }
        let message = pending.count == 1
            ? String(localized: "Added “\(title(for: pending[0]))” from the share sheet")
            : String(localized: "\(pending.count) prompts added from the share sheet")
        UndoCenter.shared.show(message)
    }

    /// The title the user gave, or the start of the prompt's first line.
    static func title(for item: ImportedPrompt) -> String {
        let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            return title
        }
        let firstLine = item.prompt
            .split(whereSeparator: \.isNewline)
            .first
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        guard firstLine.count > derivedTitleLength else { return firstLine }
        return String(firstLine.prefix(derivedTitleLength)).trimmingCharacters(in: .whitespaces) + "…"
    }
}
