//
// Created by Banghua Zhao on 25/09/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import Foundation
import OSLog
import SharingGRDB

private let logger = Logger(subsystem: "AIPrompts", category: "ContentSync")

/// Delivers new curated prompts to existing installs.
///
/// Sources:
/// 1. The bundled CSV files (new rows added in an app update).
/// 2. A remote JSON feed hosted in the GitHub repo, so new prompts can ship without an app update.
///
/// Content is keyed by its normalized title and every delivered key is recorded in
/// `syncedContents`, so each item is inserted at most once and user deletions stick.
enum ContentSync {
    static let feedURL: URL = {
        #if DEBUG
            // Point at a local copy while editing the feed, e.g. CONTENT_FEED_URL=http://localhost:8000/feed.json
            if let override = ProcessInfo.processInfo.environment["CONTENT_FEED_URL"], let url = URL(string: override) {
                return url
            }
        #endif
        return URL(string: "https://raw.githubusercontent.com/banghuazhao/ai-prompts/main/content/feed.json")!
    }()
    static let refreshInterval: TimeInterval = 6 * 60 * 60

    private static let lastFeedFetchKey = "lastContentFeedFetchDate"

    struct CuratedPrompt {
        var title: String
        var prompt: String
        var forDevs: Bool = false
        var category: String? = nil
        var addedAt: Date? = nil
    }

    struct CuratedVibePrompt {
        var app: String
        var prompt: String
        var contributor: String = ""
        var techstack: String = ""
        var addedAt: Date? = nil
    }

    /// Syncs bundled content, then the remote feed (throttled). Returns the number of inserted items.
    @discardableResult
    static func run(database: any DatabaseWriter, forceRemote: Bool = false) async -> Int {
        var inserted = 0

        let bundledPrompts = DataManager.shared.loadPromptsDraft().map {
            CuratedPrompt(title: $0.act, prompt: $0.prompt, forDevs: $0.forDevs)
        }
        let bundledVibePrompts = DataManager.shared.loadVibePromptsDraft().map {
            CuratedVibePrompt(app: $0.app, prompt: $0.prompt, contributor: $0.contributor, techstack: $0.techstack)
        }
        do {
            inserted += try apply(prompts: bundledPrompts, vibePrompts: bundledVibePrompts, database: database)
        } catch {
            logger.error("Bundled content sync failed: \(error.localizedDescription)")
        }

        if forceRemote || shouldFetchRemoteFeed {
            do {
                let feed = try await fetchFeed()
                inserted += try apply(prompts: feed.curatedPrompts, vibePrompts: feed.curatedVibePrompts, database: database)
                UserDefaults.standard.set(Date(), forKey: lastFeedFetchKey)
            } catch {
                logger.error("Remote content sync failed: \(error.localizedDescription)")
            }
        }

        if inserted > 0 {
            logger.info("Inserted \(inserted) new prompts")
        }
        return inserted
    }

    private static var shouldFetchRemoteFeed: Bool {
        guard let last = UserDefaults.standard.object(forKey: lastFeedFetchKey) as? Date else { return true }
        return Date().timeIntervalSince(last) > refreshInterval
    }

    static func apply(
        prompts: [CuratedPrompt],
        vibePrompts: [CuratedVibePrompt],
        database: any DatabaseWriter
    ) throws -> Int {
        try database.write { db in
            var known = Set(try SyncedContent.all.fetchAll(db).map(\.key))
            let categories = try PromptCategory.all.fetchAll(db)
            var inserted = 0

            for item in prompts {
                let key = ContentKey.prompt(item.title)
                guard !item.title.isEmpty, !item.prompt.isEmpty, !known.contains(key) else { continue }
                let categoryID = item.category.flatMap { category(named: $0, in: categories)?.id }
                try Prompt.insert {
                    Prompt.Draft(
                        act: item.title,
                        prompt: item.prompt,
                        forDevs: item.forDevs,
                        modifiedDate: Date(),
                        categoryID: categoryID,
                        addedDate: item.addedAt ?? Date()
                    )
                }
                .execute(db)
                try SyncedContent.insert { SyncedContent(key: key, syncedAt: Date()) }.execute(db)
                known.insert(key)
                inserted += 1
            }

            for item in vibePrompts {
                let key = ContentKey.vibePrompt(item.app)
                guard !item.app.isEmpty, !item.prompt.isEmpty, !known.contains(key) else { continue }
                try VibePrompt.insert {
                    VibePrompt.Draft(
                        app: item.app,
                        prompt: item.prompt,
                        contributor: item.contributor,
                        techstack: item.techstack,
                        modifiedDate: Date(),
                        addedDate: item.addedAt ?? Date()
                    )
                }
                .execute(db)
                try SyncedContent.insert { SyncedContent(key: key, syncedAt: Date()) }.execute(db)
                known.insert(key)
                inserted += 1
            }

            return inserted
        }
    }

    /// Matches "💼 Productivity", "Productivity" or "productivity" to the same category.
    private static func category(named name: String, in categories: [PromptCategory]) -> PromptCategory? {
        func letters(_ value: String) -> String {
            String(value.lowercased().unicodeScalars.filter { CharacterSet.letters.contains($0) })
        }
        let target = letters(name)
        guard !target.isEmpty else { return nil }
        return categories.first { letters($0.title) == target }
    }

    // MARK: - Remote feed

    struct Feed: Decodable {
        struct Item: Decodable {
            var title: String
            var prompt: String
            var forDevs: Bool?
            var category: String?
            var addedAt: String?
        }

        struct VibeItem: Decodable {
            var app: String
            var prompt: String
            var contributor: String?
            var techstack: String?
            var addedAt: String?
        }

        var version: Int
        var prompts: [Item]?
        var vibePrompts: [VibeItem]?

        private static let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter
        }()

        var curatedPrompts: [CuratedPrompt] {
            (prompts ?? []).map {
                CuratedPrompt(
                    title: $0.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    prompt: $0.prompt.trimmingCharacters(in: .whitespacesAndNewlines),
                    forDevs: $0.forDevs ?? false,
                    category: $0.category,
                    addedAt: $0.addedAt.flatMap(Self.dateFormatter.date(from:))
                )
            }
        }

        var curatedVibePrompts: [CuratedVibePrompt] {
            (vibePrompts ?? []).map {
                CuratedVibePrompt(
                    app: $0.app.trimmingCharacters(in: .whitespacesAndNewlines),
                    prompt: $0.prompt.trimmingCharacters(in: .whitespacesAndNewlines),
                    contributor: $0.contributor ?? "",
                    techstack: $0.techstack ?? "",
                    addedAt: $0.addedAt.flatMap(Self.dateFormatter.date(from:))
                )
            }
        }
    }

    static func fetchFeed() async throws -> Feed {
        var request = URLRequest(url: feedURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200 ..< 300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(Feed.self, from: data)
    }
}
