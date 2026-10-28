//
// Created by Banghua Zhao on 27/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import Foundation

/// The last few searches made in the Search tab, newest first. Stays on this device.
enum RecentSearches {
    static let limit = 8
    private static let key = "recentSearches"

    static func load() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func save(_ searches: [String]) {
        UserDefaults.standard.set(searches, forKey: key)
    }

    /// `query` moved to the front, without an earlier copy that differs only in case,
    /// and the list cut to `limit`. Blank queries leave the list as it is.
    static func adding(_ query: String, to searches: [String]) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return searches }
        let others = searches.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        return Array(([trimmed] + others).prefix(limit))
    }
}
