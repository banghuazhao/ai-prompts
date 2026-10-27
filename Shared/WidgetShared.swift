//
// Created by Banghua Zhao on 25/09/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import Foundation

// Compiled into both the app and the widget extension.
// The app writes a small JSON snapshot into the shared App Group container and the
// widgets read it, so the widget never has to open the app's database.

struct WidgetPromptItem: Codable, Hashable, Identifiable {
    enum Kind: String, Codable {
        case prompt
        case vibe
    }

    let kind: Kind
    let rowID: Int
    let title: String
    /// Cut short to keep the snapshot small; `fullText` has the rest.
    let text: String
    /// The whole prompt when `text` was cut short, for the widgets' Copy button.
    var fullText: String? = nil

    var id: String { "\(kind.rawValue)-\(rowID)" }

    /// What the widgets' Copy button puts on the clipboard.
    var copyText: String { fullText ?? text }

    /// e.g. `aiprompts://prompt/12`
    var deepLink: URL {
        URL(string: "\(WidgetShared.urlScheme)://\(kind.rawValue)/\(rowID)")!
    }

    static let sample = WidgetPromptItem(
        kind: .prompt,
        rowID: 0,
        title: "English Translator and Improver",
        text: "I want you to act as an English translator, spelling corrector and improver. I will speak to you in any language and you will detect the language, translate it and answer in the corrected and improved version of my text."
    )
}

struct WidgetSnapshot: Codable, Equatable {
    var favorites: [WidgetPromptItem]
    var daily: [WidgetPromptItem]

    /// The same prompt all day, a different one every day.
    func promptOfTheDay(for date: Date, calendar: Calendar = .current) -> WidgetPromptItem? {
        guard !daily.isEmpty else { return nil }
        let startOfDay = calendar.startOfDay(for: date)
        let dayNumber = Int(startOfDay.timeIntervalSinceReferenceDate / 86400)
        // Spread consecutive days across the list instead of walking it in order.
        let index = Int((UInt64(bitPattern: Int64(dayNumber)) &* 2_654_435_761) % UInt64(daily.count))
        return daily[index]
    }
}

enum WidgetShared {
    static let appGroupID = "group.com.appsbay.aiPrompts"
    static let urlScheme = "aiprompts"

    enum Kind {
        static let promptOfTheDay = "PromptOfTheDayWidget"
        static let favorites = "FavoritePromptsWidget"
        static let randomPromptControl = "RandomPromptControl"
    }

    /// Set by the app at launch. Intents that open the app hand their deep link to it.
    @MainActor static var openDeepLink: ((URL) -> Void)?

    // MARK: - Copy from a widget

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    private static let lastCopiedItemIDKey = "widgetLastCopiedItemID"
    private static let lastCopiedDateKey = "widgetLastCopiedDate"

    /// How long a widget shows a checkmark after its Copy button is tapped.
    static let copiedFeedbackDuration: TimeInterval = 2

    static func noteCopied(itemID: String, at date: Date = Date()) {
        defaults?.set(itemID, forKey: lastCopiedItemIDKey)
        defaults?.set(date, forKey: lastCopiedDateKey)
    }

    /// The item copied from a widget a moment ago, and when its checkmark should go away.
    static func recentCopy(at date: Date = Date()) -> (itemID: String, until: Date)? {
        guard let itemID = defaults?.string(forKey: lastCopiedItemIDKey),
              let copiedAt = defaults?.object(forKey: lastCopiedDateKey) as? Date
        else { return nil }
        let until = copiedAt.addingTimeInterval(copiedFeedbackDuration)
        return until > date ? (itemID, until) : nil
    }

    private static var snapshotURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("widget-snapshot.json")
    }

    static func loadSnapshot() -> WidgetSnapshot? {
        guard let url = snapshotURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// Returns `true` when the stored snapshot changed.
    @discardableResult
    static func saveSnapshot(_ snapshot: WidgetSnapshot) throws -> Bool {
        guard let url = snapshotURL else { return false }
        if loadSnapshot() == snapshot {
            return false
        }
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url, options: .atomic)
        return true
    }
}
