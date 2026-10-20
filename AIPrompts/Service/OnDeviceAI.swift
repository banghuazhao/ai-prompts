//
// Created by Banghua Zhao on 04/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import Foundation
import FoundationModels
import Observation

/// Entry point for Apple's on-device Foundation Models.
///
/// The app still deploys to iOS 17, so everything that touches `FoundationModels` is gated here
/// and the rest of the app only asks for `status`.
enum OnDeviceAI {
    enum Status: Equatable {
        case available
        /// Capable device, but Apple Intelligence is turned off in Settings.
        case notEnabled
        /// Apple Intelligence is on and the model is still downloading.
        case notReady
        /// The model doesn't support the current language yet.
        case unsupportedLanguage
        /// Older iOS or a device that can't run Apple Intelligence. AI entry points are hidden.
        case unsupported
    }

    static var status: Status {
        guard #available(iOS 26.0, *) else { return .unsupported }
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return model.supportsLocale() ? .available : .unsupportedLanguage
        case .unavailable(.appleIntelligenceNotEnabled):
            return .notEnabled
        case .unavailable(.modelNotReady):
            return .notReady
        case .unavailable:
            return .unsupported
        }
    }

    /// Whether AI entry points should be shown at all.
    static var isSupported: Bool {
        status != .unsupported
    }
}

/// A user-facing explanation of why a response failed.
struct OnDeviceAIFailure: Equatable {
    enum Kind {
        /// The model declined the prompt; other assistants may still handle it.
        case declined
        /// The conversation no longer fits in the context window.
        case conversationTooLong
        case other
    }

    let kind: Kind
    let message: String
}

/// A multi-turn chat with the on-device model that streams each reply into `messages`.
@available(iOS 26.0, *)
@Observable
@MainActor
final class OnDeviceChat {
    private(set) var messages: [AIMessage] = []
    private(set) var isResponding = false
    private(set) var failure: OnDeviceAIFailure?

    @ObservationIgnored private var session: LanguageModelSession
    @ObservationIgnored private var responseTask: Task<Void, Never>?

    /// Starts a new chat, or continues a saved one when `history` isn't empty.
    init(history: [AIMessage] = []) {
        messages = history
        session = Self.makeSession(history: history)
    }

    private static let instructions = """
    You are a helpful assistant inside the AI Prompts app. The user's first message is usually \
    a prompt from a prompt library: follow it as written. If it asks you to act as a role, \
    stay in that role for the rest of the conversation. Reply in the same language as the \
    user's message. Use Markdown for emphasis and code where it helps.
    """

    private static func makeSession(history: [AIMessage] = []) -> LanguageModelSession {
        let turns = turnsToRestore(from: history)
        guard !turns.isEmpty else {
            return LanguageModelSession(instructions: instructions)
        }
        var entries: [Transcript.Entry] = [
            .instructions(Transcript.Instructions(segments: [.text(.init(content: instructions))], toolDefinitions: []))
        ]
        for turn in turns {
            entries.append(.prompt(Transcript.Prompt(segments: [.text(.init(content: turn.prompt))])))
            entries.append(.response(Transcript.Response(assetIDs: [], segments: [.text(.init(content: turn.response))])))
        }
        return LanguageModelSession(transcript: Transcript(entries: entries))
    }

    /// The turns of a saved chat that fit in about half the context window, leaving the rest for
    /// the next prompt and reply: the first turn, which usually sets up the role, then as many
    /// recent turns as fit. Older turns stay on screen but the model no longer sees them.
    private static func turnsToRestore(from history: [AIMessage]) -> [(prompt: String, response: String)] {
        var turns: [(prompt: String, response: String)] = []
        for (index, message) in history.enumerated() where message.role == .user {
            let next = history.indices.contains(index + 1) ? history[index + 1] : nil
            if let next, next.role == .assistant, !next.text.isEmpty {
                turns.append((message.text, next.text))
            }
        }
        guard let first = turns.first else { return [] }

        var budget = SystemLanguageModel.default.contextSize / 2
        func cost(_ turn: (prompt: String, response: String)) -> Int {
            estimatedTokens(turn.prompt) + estimatedTokens(turn.response)
        }

        var restored: [(prompt: String, response: String)] = []
        let keepsFirst = cost(first) <= budget / 2
        if keepsFirst {
            budget -= cost(first)
        }
        for turn in turns.dropFirst(keepsFirst ? 1 : 0).reversed() {
            guard cost(turn) <= budget else { break }
            budget -= cost(turn)
            restored.insert(turn, at: 0)
        }
        return keepsFirst ? [first] + restored : restored
    }

    /// A rough token count that errs high: about four Latin characters per token, and one
    /// token per character for scripts like Chinese or Japanese.
    private static func estimatedTokens(_ text: String) -> Int {
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

    func send(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isResponding else { return }

        failure = nil
        let reply = AIMessage(role: .assistant, text: "")
        messages.append(AIMessage(role: .user, text: text))
        messages.append(reply)
        isResponding = true

        // The reply is looked up by id because `startOver()` can clear `messages` mid-stream.
        responseTask = Task {
            do {
                for try await snapshot in session.streamResponse(to: text) {
                    guard let index = messages.firstIndex(where: { $0.id == reply.id }) else { return }
                    messages[index].text = snapshot.content
                }
            } catch is CancellationError {
                // Keep whatever was streamed before the user tapped stop.
            } catch {
                failure = OnDeviceAIFailure(error)
            }
            guard let index = messages.firstIndex(where: { $0.id == reply.id }) else { return }
            if messages[index].text.isEmpty {
                messages.remove(at: index)
            }
            isResponding = false
        }
    }

    /// Sends the last user message again after a failure.
    func retry() {
        guard !isResponding, let last = messages.last, last.role == .user else { return }
        messages.removeLast()
        send(last.text)
    }

    func stop() {
        responseTask?.cancel()
    }

    /// Clears the conversation and starts a fresh session (and context window).
    func startOver() {
        stop()
        session = Self.makeSession()
        messages = []
        failure = nil
        isResponding = false
    }
}

@available(iOS 26.0, *)
extension OnDeviceAIFailure {
    init(_ error: Error) {
        guard let error = error as? LanguageModelSession.GenerationError else {
            self.init(kind: .other, message: error.localizedDescription)
            return
        }
        switch error {
        case .guardrailViolation, .refusal:
            self.init(
                kind: .declined,
                message: String(localized: "Apple Intelligence can't help with this prompt. Try it in another assistant instead.")
            )
        case .exceededContextWindowSize:
            self.init(
                kind: .conversationTooLong,
                message: String(localized: "This conversation is too long for the on-device model. Start a new chat to keep going.")
            )
        case .unsupportedLanguageOrLocale:
            self.init(
                kind: .declined,
                message: String(localized: "Apple Intelligence doesn't support this language yet.")
            )
        case .assetsUnavailable:
            self.init(
                kind: .other,
                message: String(localized: "Apple Intelligence is still getting ready. Try again in a moment.")
            )
        case .rateLimited, .concurrentRequests:
            self.init(
                kind: .other,
                message: String(localized: "Apple Intelligence is busy. Try again in a moment.")
            )
        default:
            self.init(kind: .other, message: error.localizedDescription)
        }
    }
}
