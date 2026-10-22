//
// Created by Banghua Zhao on 21/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

@testable import AIPrompts
import Testing

/// The on-device model's context window on iOS 26, in tokens.
private let contextSize = 4096

private func user(_ text: String) -> AIMessage {
    AIMessage(role: .user, text: text)
}

private func assistant(_ text: String) -> AIMessage {
    AIMessage(role: .assistant, text: text)
}

/// A chat of `count` turns, each about `tokens` estimated tokens per message.
private func chat(turns count: Int, tokensPerMessage tokens: Int = 50) -> [AIMessage] {
    (0 ..< count).flatMap { index in
        [
            user("Question \(index) " + String(repeating: "word ", count: tokens * 4 / 5)),
            assistant("Answer \(index) " + String(repeating: "word ", count: tokens * 4 / 5)),
        ]
    }
}

struct EstimatedTokensTests {
    @Test func countsAboutFourLatinCharactersPerToken() {
        #expect(ChatContext.estimatedTokens("") == 1)
        #expect(ChatContext.estimatedTokens(String(repeating: "abcd", count: 10)) == 11)
    }

    @Test func countsOneTokenPerCharacterForOtherScripts() {
        #expect(ChatContext.estimatedTokens("你好") == 3)
        #expect(ChatContext.estimatedTokens("こんにちは") == 6)
    }
}

struct ClippedTests {
    @Test func leavesShortTextAlone() {
        #expect(ChatContext.clipped("Hello there", toTokens: 100) == "Hello there")
    }

    @Test(arguments: ["latin", "japanese", "mixed"])
    func cutsLongTextToTheLimitIncludingTheEllipsis(script: String) {
        let text = switch script {
        case "latin": String(repeating: "word ", count: 2_000)
        case "japanese": String(repeating: "長い文章です。", count: 500)
        default: String(repeating: "mixed 混合 text ", count: 400)
        }
        for limit in [10, 100, 500] {
            let clipped = ChatContext.clipped(text, toTokens: limit)
            #expect(clipped.hasSuffix("…"))
            #expect(ChatContext.estimatedTokens(clipped) <= limit)
            #expect(text.hasPrefix(String(clipped.dropLast())))
        }
    }
}

struct TurnsTests {
    @Test func pairsEachMessageWithItsReply() {
        let turns = ChatContext.turns(in: [user("A"), assistant("1"), user("B"), assistant("2")])
        #expect(turns == [.init(prompt: "A", response: "1"), .init(prompt: "B", response: "2")])
    }

    @Test func leavesOutUnansweredMessagesAndEmptyReplies() {
        let turns = ChatContext.turns(in: [
            assistant("stray"), user("A"), assistant(""), user("B"), user("C"), assistant("3"), user("D"),
        ])
        #expect(turns == [.init(prompt: "C", response: "3")])
    }
}

struct TurnsToRestoreTests {
    @Test func restoresNothingWithoutReplies() {
        #expect(ChatContext.turnsToRestore(from: [], contextSize: contextSize).isEmpty)
        #expect(ChatContext.turnsToRestore(from: [user("Hi")], contextSize: contextSize).isEmpty)
    }

    @Test func restoresAShortChatInFull() {
        let messages = chat(turns: 3)
        let restored = ChatContext.turnsToRestore(from: messages, contextSize: contextSize)
        #expect(restored == ChatContext.turns(in: messages))
    }

    @Test func keepsTheFirstAndLatestTurnsOfALongChat() {
        let messages = chat(turns: 40)
        let all = ChatContext.turns(in: messages)
        let restored = ChatContext.turnsToRestore(from: messages, contextSize: contextSize)

        #expect(restored.count < all.count)
        #expect(restored.first == all.first)
        #expect(restored.last == all.last)
        // Apart from the first turn, the restored turns are the latest ones, without gaps.
        #expect(Array(restored.dropFirst()) == Array(all.suffix(restored.count - 1)))
        #expect(restored.map(\.estimatedTokens).reduce(0, +) <= contextSize / 2)
    }

    @Test func dropsAFirstTurnThatTakesTooMuchOfTheBudget() {
        let messages = [user(String(repeating: "setup ", count: 2_000)), assistant("OK")] + chat(turns: 3)
        let restored = ChatContext.turnsToRestore(from: messages, contextSize: contextSize)
        #expect(restored == ChatContext.turns(in: chat(turns: 3)))
    }
}

struct SummaryPlanTests {
    @Test func needsAReplyToSummarize() {
        #expect(ChatContext.summaryPlan(for: []) == nil)
        #expect(ChatContext.summaryPlan(for: [user("A very long prompt")]) == nil)
        #expect(ChatContext.summaryPlan(for: [user("A"), assistant("")]) == nil)
    }

    @Test func resendsTheUnansweredMessage() throws {
        let messages = [user("A"), assistant("1"), user("B")]
        let plan = try #require(ChatContext.summaryPlan(for: messages))
        #expect(plan.resend == "B")
        #expect(plan.earlier.map(\.text) == ["A", "1"])
    }

    @Test func resendsNothingWhenTheLastReplyWasCutOff() throws {
        let messages = [user("A"), assistant("1"), user("B"), assistant("partial")]
        let plan = try #require(ChatContext.summaryPlan(for: messages))
        #expect(plan.resend == nil)
        #expect(plan.earlier.map(\.text) == ["A", "1", "B", "partial"])
    }
}

struct SummaryExcerptTests {
    @Test func includesAShortChatInFull() {
        let excerpt = ChatContext.summaryExcerpt(of: [user("A"), assistant("1")], contextSize: contextSize)
        #expect(excerpt == "User: A\n\nAssistant: 1")
    }

    @Test func keepsTheOpeningAndLatestMessagesWithinHalfTheWindow() {
        let messages = [user("Act as a travel planner.")] + chat(turns: 60).dropFirst()
        let excerpt = ChatContext.summaryExcerpt(of: messages, contextSize: contextSize)

        #expect(excerpt.hasPrefix("User: Act as a travel planner."))
        #expect(excerpt.hasSuffix(messages.last!.text))
        #expect(!excerpt.contains("Answer 1 "))
        #expect(ChatContext.estimatedTokens(excerpt) <= contextSize / 2)
    }

    @Test func clipsVeryLongMessages() {
        let messages = [user(String(repeating: "很長的提示詞。", count: 1_000)), assistant(String(repeating: "word ", count: 5_000))]
        let excerpt = ChatContext.summaryExcerpt(of: messages, contextSize: contextSize)
        #expect(excerpt.contains("…"))
        #expect(ChatContext.estimatedTokens(excerpt) <= contextSize / 2)
    }
}

struct TurnsAfterSummaryTests {
    @Test func keepsTheLatestTurnWhenItIsShort() {
        let turns = ChatContext.turnsAfterSummary(of: chat(turns: 5), contextSize: contextSize)
        #expect(turns == Array(ChatContext.turns(in: chat(turns: 5)).suffix(1)))
    }

    @Test func dropsALatestTurnThatIsTooLong() {
        let messages = chat(turns: 2) + [user("Q"), assistant(String(repeating: "word ", count: 5_000))]
        #expect(ChatContext.turnsAfterSummary(of: messages, contextSize: contextSize).isEmpty)
    }
}
