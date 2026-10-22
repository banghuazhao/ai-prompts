//
// Created by Banghua Zhao on 21/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import Foundation

/// Decides how much of a conversation the on-device model sees, given its context window size
/// in tokens. Kept free of `FoundationModels` so it can be tested without Apple Intelligence.
enum ChatContext {
    /// A user message and the reply that followed it.
    struct Turn: Equatable {
        let prompt: String
        let response: String

        var estimatedTokens: Int {
            ChatContext.estimatedTokens(prompt) + ChatContext.estimatedTokens(response)
        }
    }

    /// A rough token count that errs high: about four Latin characters per token, and one
    /// token per character for scripts like Chinese or Japanese.
    static func estimatedTokens(_ text: String) -> Int {
        var ascii = 0
        var other = 0
        for scalar in text.unicodeScalars {
            if scalar.isASCII {
                ascii += 1
            } else {
                other += 1
            }
        }
        return ascii / 4 + other + 1
    }

    /// `text` cut down to at most `maxTokens` estimated tokens, ending in "…" when cut.
    static func clipped(_ text: String, toTokens maxTokens: Int) -> String {
        guard estimatedTokens(text) > maxTokens else { return text }
        var keep = text.count * maxTokens / estimatedTokens(text)
        while keep > 0 {
            let candidate = String(text.prefix(keep)) + "…"
            if estimatedTokens(candidate) <= maxTokens {
                return candidate
            }
            keep -= max(1, keep / 10)
        }
        return "…"
    }

    /// Each user message with the reply that followed it. Unanswered messages are left out.
    static func turns(in messages: [AIMessage]) -> [Turn] {
        var turns: [Turn] = []
        for (index, message) in messages.enumerated() where message.role == .user {
            let next = messages.indices.contains(index + 1) ? messages[index + 1] : nil
            if let next, next.role == .assistant, !next.text.isEmpty {
                turns.append(Turn(prompt: message.text, response: next.text))
            }
        }
        return turns
    }

    /// The turns of a saved chat that fit in about half the context window, leaving the rest for
    /// the next prompt and reply: the first turn, which usually sets up the role, then as many
    /// recent turns as fit. Older turns stay on screen but the model no longer sees them.
    static func turnsToRestore(from history: [AIMessage], contextSize: Int) -> [Turn] {
        let turns = turns(in: history)
        guard let first = turns.first else { return [] }

        var budget = contextSize / 2
        var restored: [Turn] = []
        let keepsFirst = first.estimatedTokens <= budget / 2
        if keepsFirst {
            budget -= first.estimatedTokens
        }
        for turn in turns.dropFirst(keepsFirst ? 1 : 0).reversed() {
            guard turn.estimatedTokens <= budget else { break }
            budget -= turn.estimatedTokens
            restored.insert(turn, at: 0)
        }
        return keepsFirst ? [first] + restored : restored
    }

    /// What continuing with a summary works from: the messages to summarize, and the unanswered
    /// message to send again afterwards, if the chat ends with one. Nil when there's no reply
    /// to summarize yet.
    static func summaryPlan(for messages: [AIMessage]) -> (earlier: [AIMessage], resend: String?)? {
        let resend = messages.last?.role == .user ? messages.last?.text : nil
        let earlier = resend == nil ? messages : Array(messages.dropLast())
        guard earlier.contains(where: { $0.role == .assistant && !$0.text.isEmpty }) else { return nil }
        return (earlier, resend)
    }

    /// The part of `messages` sent to the model to summarize, within half the context window:
    /// the opening message, which usually sets up the role, then as many of the latest messages
    /// as fit. Each message is clipped to a quarter of that budget.
    static func summaryExcerpt(of messages: [AIMessage], contextSize: Int) -> String {
        let budget = contextSize / 2
        func line(_ message: AIMessage) -> String {
            let speaker = message.role == .user ? "User" : "Assistant"
            return "\(speaker): \(clipped(message.text, toTokens: budget / 4))"
        }

        guard let first = messages.first else { return "" }
        let opening = line(first)
        var remaining = budget - estimatedTokens(opening)
        var latest: [String] = []
        for message in messages.dropFirst().reversed() {
            let text = line(message)
            // One more token for the blank line that joins it to the rest.
            let cost = estimatedTokens(text) + 1
            guard cost <= remaining else { break }
            remaining -= cost
            latest.insert(text, at: 0)
        }
        return ([opening] + latest).joined(separator: "\n\n")
    }

    /// The latest turn, kept word for word next to the summary when it fits in a quarter of the
    /// context window.
    static func turnsAfterSummary(of messages: [AIMessage], contextSize: Int) -> [Turn] {
        turns(in: messages).suffix(1).filter { $0.estimatedTokens <= contextSize / 4 }
    }
}
