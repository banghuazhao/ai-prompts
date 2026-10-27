//
// Created by Banghua Zhao on 27/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import Foundation

/// Matches a typed query against an item's title and other fields, word by word, ignoring
/// case, accents and full-width forms. Every word must appear somewhere, in any order.
///
/// Results are ranked so the most likely match comes first: the title starting with the query,
/// then the title containing the whole query, then titles containing more of its words.
struct TextSearch {
    /// The query as typed, trimmed.
    let query: String
    /// The query split on whitespace.
    let terms: [String]

    private static let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]

    init(_ query: String) {
        self.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        terms = self.query.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    var isEmpty: Bool { terms.isEmpty }

    /// How well an item matches, higher is better, or nil when a word of the query is missing
    /// from every field. An empty query matches everything with a score of 0.
    func score(title: String, fields: [String]) -> Int? {
        guard !isEmpty else { return 0 }
        var total = 0
        for term in terms {
            if title.range(of: term, options: Self.options) != nil {
                total += 10
            } else if fields.contains(where: { $0.range(of: term, options: Self.options) != nil }) {
                total += 1
            } else {
                return nil
            }
        }
        if title.range(of: query, options: Self.options.union(.anchored)) != nil {
            total += 100
        } else if terms.count > 1, title.range(of: query, options: Self.options) != nil {
            total += 50
        }
        return total
    }

    func matches(title: String, fields: [String]) -> Bool {
        score(title: title, fields: fields) != nil
    }

    /// The items that match, best first. Items that score the same keep their order in `items`,
    /// so sort them the way ties should break before calling this.
    func rank<Item>(
        _ items: [Item],
        title: (Item) -> String,
        fields: (Item) -> [String]
    ) -> [Item] {
        guard !isEmpty else { return items }
        var scored: [ScoredItem<Item>] = []
        for (offset, item) in items.enumerated() {
            if let value = self.score(title: title(item), fields: fields(item)) {
                scored.append(ScoredItem(offset: offset, score: value, item: item))
            }
        }
        scored.sort { lhs, rhs in
            lhs.score != rhs.score ? lhs.score > rhs.score : lhs.offset < rhs.offset
        }
        return scored.map { $0.item }
    }

    private struct ScoredItem<Item> {
        let offset: Int
        let score: Int
        let item: Item
    }
}
