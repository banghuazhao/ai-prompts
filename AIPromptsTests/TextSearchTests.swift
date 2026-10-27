//
// Created by Banghua Zhao on 27/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

@testable import AIPrompts
import Testing

private struct Item: Equatable {
    let title: String
    var body = ""
}

private func titles(_ query: String, in items: [Item]) -> [String] {
    TextSearch(query).rank(items, title: { $0.title }, fields: { [$0.body] }).map(\.title)
}

struct TextSearchTests {
    @Test func emptyQueryKeepsEverythingInOrder() {
        let items = [Item(title: "B"), Item(title: "A")]
        #expect(TextSearch("   ").isEmpty)
        #expect(titles("  ", in: items) == ["B", "A"])
    }

    @Test func everyWordMustMatchInAnyOrder() {
        let items = [
            Item(title: "Travel Guide", body: "Suggest places to visit on a trip"),
            Item(title: "Trip Planner", body: "Plan a budget"),
            Item(title: "Poet"),
        ]
        #expect(titles("visit travel", in: items) == ["Travel Guide"])
        #expect(titles("trip", in: items) == ["Trip Planner", "Travel Guide"])
        #expect(titles("poet trip", in: items).isEmpty)
    }

    @Test func ignoresCaseAccentsAndWidth() {
        let items = [Item(title: "Café Menu Writer"), Item(title: "ＡＢＣ Tutor")]
        #expect(titles("CAFE", in: items) == ["Café Menu Writer"])
        #expect(titles("abc", in: items) == ["ＡＢＣ Tutor"])
    }

    @Test func titleMatchesRankAboveBodyMatches() {
        let items = [
            Item(title: "Storyteller", body: "Write an essay as a story"),
            Item(title: "Essay Writer"),
        ]
        #expect(titles("essay", in: items) == ["Essay Writer", "Storyteller"])
    }

    @Test func titleStartingWithQueryComesFirst() {
        let items = [
            Item(title: "Senior Python Developer"),
            Item(title: "Python Interpreter"),
        ]
        #expect(titles("python", in: items) == ["Python Interpreter", "Senior Python Developer"])
    }

    @Test func wholePhraseInTitleBeatsScatteredWords() {
        let items = [
            Item(title: "Plan Your Day Trip"),
            Item(title: "Day Trip Planner"),
            Item(title: "Weekly Trip Day Log"),
        ]
        #expect(titles("trip planner", in: items).first == "Day Trip Planner")
        #expect(titles("day trip", in: items) == ["Day Trip Planner", "Plan Your Day Trip", "Weekly Trip Day Log"])
    }

    @Test func tiesKeepTheIncomingOrder() {
        let items = [Item(title: "Zed Coach"), Item(title: "Alpha Coach"), Item(title: "Mid Coach")]
        #expect(titles("coach", in: items) == ["Zed Coach", "Alpha Coach", "Mid Coach"])
    }

    @Test func matchesTextWithoutSpaces() {
        let items = [Item(title: "英语翻译", body: "我希望你充当英语翻译员"), Item(title: "面试官")]
        #expect(titles("翻译", in: items) == ["英语翻译"])
    }
}

struct RecentSearchesTests {
    @Test func newestFirstWithoutCaseDuplicates() {
        let searches = RecentSearches.adding("  Email ", to: ["code", "email", "trip"])
        #expect(searches == ["Email", "code", "trip"])
    }

    @Test func blankQueriesAreIgnored() {
        #expect(RecentSearches.adding("   ", to: ["code"]) == ["code"])
    }

    @Test func keepsOnlyTheLimit() {
        let existing = (1 ... RecentSearches.limit).map { "search \($0)" }
        let searches = RecentSearches.adding("new", to: existing)
        #expect(searches.count == RecentSearches.limit)
        #expect(searches.first == "new")
        #expect(!searches.contains("search \(RecentSearches.limit)"))
    }
}
