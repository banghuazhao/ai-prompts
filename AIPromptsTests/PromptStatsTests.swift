//
// Created by Banghua Zhao on 27/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

@testable import AIPrompts
import Testing

struct PromptStatsTests {
    @Test func emptyTextHasNothing() {
        #expect(PromptStats("").words == 0)
        #expect(PromptStats("").estimatedTokens == 0)
    }

    @Test func countsWordsNotPunctuation() {
        let stats = PromptStats("Write a short poem about the sea.")
        #expect(stats.words == 7)
        #expect(stats.estimatedTokens == ChatContext.estimatedTokens("Write a short poem about the sea."))
    }

    @Test func countsWordsInTextWithoutSpaces() {
        #expect(PromptStats("我希望你充当英语翻译员").words > 1)
    }
}
