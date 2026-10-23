//
// Created by Banghua Zhao on 23/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

@testable import AIPrompts
import Testing

struct MarkdownBlockTests {
    @Test func plainTextIsOneParagraph() {
        #expect(MarkdownBlock.parse("Hello **there**.\nSecond line.") == [.paragraph("Hello **there**.\nSecond line.")])
    }

    @Test func blankLinesSeparateParagraphs() {
        #expect(MarkdownBlock.parse("One\n\n\nTwo") == [.paragraph("One"), .paragraph("Two")])
        #expect(MarkdownBlock.parse("").isEmpty)
    }

    @Test func headings() {
        #expect(MarkdownBlock.parse("# Title\n### Small ###\nText") == [
            .heading(level: 1, text: "Title"),
            .heading(level: 3, text: "Small"),
            .paragraph("Text"),
        ])
    }

    @Test func hashesWithoutASpaceAreNotAHeading() {
        #expect(MarkdownBlock.parse("#hashtag") == [.paragraph("#hashtag")])
        #expect(MarkdownBlock.parse("####### seven") == [.paragraph("####### seven")])
    }

    @Test func bulletList() {
        #expect(MarkdownBlock.parse("- One\n* Two\n+ Three") == [
            .list(start: nil, items: [
                .init(depth: 0, text: "One"), .init(depth: 0, text: "Two"), .init(depth: 0, text: "Three"),
            ]),
        ])
    }

    @Test func orderedListKeepsItsStartNumber() {
        #expect(MarkdownBlock.parse("3. Three\n4) Four") == [
            .list(start: 3, items: [.init(depth: 0, text: "Three"), .init(depth: 0, text: "Four")]),
        ])
    }

    @Test func nestedItemsStayInTheirList() {
        let blocks = MarkdownBlock.parse("1. Plan\n   - Monday\n   - Tuesday\n2. Review")
        #expect(blocks == [
            .list(start: 1, items: [
                .init(depth: 0, text: "Plan"),
                .init(depth: 1, text: "Monday"),
                .init(depth: 1, text: "Tuesday"),
                .init(depth: 0, text: "Review"),
            ]),
        ])
    }

    @Test func switchingFromNumbersToBulletsStartsANewList() {
        #expect(MarkdownBlock.parse("1. One\n- Bullet") == [
            .list(start: 1, items: [.init(depth: 0, text: "One")]),
            .list(start: nil, items: [.init(depth: 0, text: "Bullet")]),
        ])
    }

    @Test func indentedLineContinuesAListItem() {
        #expect(MarkdownBlock.parse("- First line\n  wraps here\n\nAfter") == [
            .list(start: nil, items: [.init(depth: 0, text: "First line\nwraps here")]),
            .paragraph("After"),
        ])
    }

    @Test func listRightAfterAParagraph() {
        #expect(MarkdownBlock.parse("Steps:\n- Boil water") == [
            .paragraph("Steps:"),
            .list(start: nil, items: [.init(depth: 0, text: "Boil water")]),
        ])
    }

    @Test func fencedCodeKeepsItsContentAsIs() {
        let markdown = "Run:\n```swift\nlet x = 1\n\n# not a heading\n- not a list\n```\nDone"
        #expect(MarkdownBlock.parse(markdown) == [
            .paragraph("Run:"),
            .code(language: "swift", code: "let x = 1\n\n# not a heading\n- not a list"),
            .paragraph("Done"),
        ])
    }

    @Test func unclosedFenceWhileStreamingRunsToTheEnd() {
        #expect(MarkdownBlock.parse("```\nprint(1)\nprint(2") == [.code(language: nil, code: "print(1)\nprint(2")])
    }

    @Test func quoteSpansConsecutiveLines() {
        #expect(MarkdownBlock.parse("> One\n> Two\nAfter") == [.quote("One\nTwo"), .paragraph("After")])
    }

    @Test func tableWithAHeader() {
        #expect(MarkdownBlock.parse("| A | B |\n|:--|--:|\n| 1 | **2** |\nAfter") == [
            .table(header: ["A", "B"], rows: [["1", "**2**"]]),
            .paragraph("After"),
        ])
    }

    @Test func tableWithoutASeparatorRowHasNoHeader() {
        #expect(MarkdownBlock.parse("| 1 | 2 |\n| 3 | 4 |") == [.table(header: [], rows: [["1", "2"], ["3", "4"]])])
    }

    @Test func plainTextDropsTheMarkup() {
        let markdown = "# Lighthouse\n\nThree **bold** ideas:\n1. *Film* photo\n- `code`\n\n---\n> Quote"
        #expect(MarkdownBlock.plainText(markdown) == "Lighthouse\nThree bold ideas:\nFilm photo\ncode\nQuote")
    }

    @Test func horizontalRules() {
        #expect(MarkdownBlock.parse("Above\n\n---\n\n* * *\nBelow") == [.paragraph("Above"), .rule, .rule, .paragraph("Below")])
    }

    @Test func windowsLineEndings() {
        #expect(MarkdownBlock.parse("# Title\r\n- Item") == [
            .heading(level: 1, text: "Title"),
            .list(start: nil, items: [.init(depth: 0, text: "Item")]),
        ])
    }
}
