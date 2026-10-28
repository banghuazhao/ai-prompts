//
// Created by Banghua Zhao on 27/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

@testable import AIPrompts
import Testing

private func kinds(_ text: String) -> [PromptIssue.Kind] {
    PromptAnalyzer.analyze(text).map(\.kind)
}

/// A detailed English prompt with a format, an audience, an example and steps.
private let goodPrompt = """
You are an experienced travel planner. Plan a three day trip to Kyoto for two students on a small \
budget who love food and history. First suggest where to stay, then list the main sights for each \
day, and finally add two restaurants per day, for example a ramen shop near the station. Format \
the plan as a table with one row per day and keep it under 300 words so it is easy to read.
"""

struct PromptAnalyzerTests {
    @Test func emptyTextHasNoIssues() {
        #expect(kinds("   ").isEmpty)
    }

    @Test func shortPromptsAreFlagged() {
        #expect(kinds("Fix it") == [.tooShort])
    }

    @Test func detailedPromptPasses() {
        #expect(kinds(goodPrompt).isEmpty)
    }

    @Test func wordsInsideOtherWordsDontCount() {
        // "everything" used to count as both "thing" and "everything".
        let text = "Explain everything about photosynthesis to me in simple terms, please, with care."
        #expect(!kinds(text).contains(.vagueWords))
        #expect(PromptAnalyzer.containsWholePhrase("who", in: "the whole story") == false)
        #expect(PromptAnalyzer.containsWholePhrase("e.g.", in: "Use a color, e.g. blue.") == true)
    }

    @Test func vagueWordsAreFlaggedWhenRepeated() {
        #expect(kinds("Tell me some things about stuff in history and art today.").contains(.vagueWords))
    }

    @Test func repeatedSentencesAreFlaggedInAnyLanguage() {
        #expect(kinds("Write a poem about the sea. Write a poem about the sea.").contains(.repeatedSentences))
        #expect(kinds("请写一首关于大海的诗。请写一首关于大海的诗。").contains(.repeatedSentences))
    }

    @Test func englishOnlyChecksSkipOtherLanguages() {
        let chinese = String(repeating: "我希望你充当一名经验丰富的旅行规划师，为我规划一次去京都的三天旅行。", count: 4)
        let issues = kinds(chinese)
        #expect(!issues.contains(.noOutputFormat))
        #expect(!issues.contains(.noAudience))
    }

    @Test func longPromptWithoutFormatIsFlagged() {
        let text = String(repeating: "Help me plan a relaxing weekend at home with my partner and our dog. ", count: 4)
        #expect(kinds(text).contains(.noOutputFormat))
    }

    @Test func listMarkersCountAsStructure() {
        #expect(PromptAnalyzer.hasListMarkers("Do this:\n- one\n- two"))
        #expect(PromptAnalyzer.hasListMarkers("Do this:\n1. one\n2) two"))
        #expect(!PromptAnalyzer.hasListMarkers("A sentence - with a dash in it."))
    }
}
