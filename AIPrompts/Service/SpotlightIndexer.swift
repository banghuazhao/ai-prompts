//
// Created by Banghua Zhao on 05/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import AppIntents
import CoreSpotlight
import CryptoKit
import Foundation
import OSLog

private let logger = Logger(subsystem: "AIPrompts", category: "Spotlight")

/// Keeps every prompt searchable in Spotlight (iOS 18+).
@MainActor
enum SpotlightIndexer {
    private static let signatureKey = "spotlightIndexSignature"
    private static let indexedIDsKey = "spotlightIndexedIDs"

    /// Updates run one after another, so a launch update and a background update can't interleave.
    private static var latestUpdate: Task<Void, Never>?

    /// Re-indexes the library when it changed since the last run.
    static func update() async {
        let previous = latestUpdate
        let update = Task {
            await previous?.value
            await reindexIfNeeded()
        }
        latestUpdate = update
        await update.value
    }

    private static func reindexIfNeeded() async {
        guard #available(iOS 18.0, *) else { return }
        let defaults = UserDefaults.standard
        do {
            let entities = try PromptEntity.all()
            let signature = signature(for: entities)
            guard defaults.string(forKey: signatureKey) != signature else { return }

            let index = CSSearchableIndex.default()
            // Indexing replaces items with the same id, so only deleted prompts need removing.
            let ids = Set(entities.map(\.id))
            let removedIDs = Set(defaults.stringArray(forKey: indexedIDsKey) ?? []).subtracting(ids)
            if !removedIDs.isEmpty {
                try await index.deleteAppEntities(identifiedBy: Array(removedIDs), ofType: PromptEntity.self)
            }
            try await index.indexAppEntities(entities)

            defaults.set(Array(ids), forKey: indexedIDsKey)
            defaults.set(signature, forKey: signatureKey)
        } catch {
            logger.error("Failed to index prompts: \(error.localizedDescription)")
        }
    }

    private static func signature(for entities: [PromptEntity]) -> String {
        let summary = entities
            .map { "\($0.id)|\($0.title)|\($0.modifiedDate.timeIntervalSinceReferenceDate)" }
            .sorted()
            .joined(separator: "\n")
        return SHA256.hash(data: Data(summary.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
