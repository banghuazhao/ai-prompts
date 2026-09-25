//
// Created by Banghua Zhao on 25/09/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import Foundation
import SharingGRDB

/// Remembers every piece of curated content that has ever been delivered to this device,
/// so content updates only insert what is genuinely new and never resurrect deleted prompts.
@Table
struct SyncedContent {
    var key: String
    var syncedAt: Date = Date()
}

enum ContentKey {
    /// How long newly delivered prompts are highlighted as "New".
    static let newContentWindow: TimeInterval = 14 * 24 * 60 * 60

    static func prompt(_ title: String) -> String {
        "prompt:" + normalize(title)
    }

    static func vibePrompt(_ app: String) -> String {
        "vibe:" + normalize(app)
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
