//
// Created by Banghua Zhao on 27/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

@testable import AIPrompts
import Testing

struct ImportedPromptTests {
    @Test func blankTextIsNothing() {
        #expect(ImportedPrompt(text: " \n ") == nil)
    }

    @Test func shortFirstLineBecomesTheTitle() {
        let imported = ImportedPrompt(text: "## **Travel Guide**\nAct as a travel guide for {{city}}.\n\nBe brief.")
        #expect(imported == ImportedPrompt(title: "Travel Guide", prompt: "Act as a travel guide for {{city}}.\n\nBe brief."))
    }

    @Test func windowsLineEndingsSplitToo() {
        let imported = ImportedPrompt(text: "Poet\r\nWrite a poem.")
        #expect(imported?.title == "Poet")
        #expect(imported?.prompt == "Write a poem.")
    }

    @Test func singleLineHasNoTitle() {
        #expect(ImportedPrompt(text: "  Write a poem about rain.  ") == ImportedPrompt(title: "", prompt: "Write a poem about rain."))
    }

    @Test func longFirstLineStaysInThePrompt() {
        let firstLine = String(repeating: "word ", count: 20).trimmingCharacters(in: .whitespaces)
        let imported = ImportedPrompt(text: firstLine + "\nMore text.")
        #expect(imported?.title == "")
        #expect(imported?.prompt == firstLine + "\nMore text.")
    }

    @MainActor
    @Test func sharedPromptsWithoutTitleGetOneFromTheirText() {
        #expect(SharedInboxImporter.title(for: ImportedPrompt(title: " Coach ", prompt: "x")) == "Coach")
        #expect(SharedInboxImporter.title(for: ImportedPrompt(title: "", prompt: "Short prompt\nmore")) == "Short prompt")
        let long = String(repeating: "a", count: SharedInboxImporter.derivedTitleLength + 10)
        let title = SharedInboxImporter.title(for: ImportedPrompt(title: "", prompt: long))
        #expect(title.count == SharedInboxImporter.derivedTitleLength + 1)
        #expect(title.hasSuffix("…"))
    }
}
