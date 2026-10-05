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

    @ObservationIgnored private var session = OnDeviceChat.makeSession()
    @ObservationIgnored private var responseTask: Task<Void, Never>?

    private static func makeSession() -> LanguageModelSession {
        LanguageModelSession(instructions: """
        You are a helpful assistant inside the AI Prompts app. The user's first message is usually \
        a prompt from a prompt library: follow it as written. If it asks you to act as a role, \
        stay in that role for the rest of the conversation. Reply in the same language as the \
        user's message. Use Markdown for emphasis and code where it helps.
        """)
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
                failure = Self.failure(for: error)
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

    private static func failure(for error: Error) -> OnDeviceAIFailure {
        guard let error = error as? LanguageModelSession.GenerationError else {
            return OnDeviceAIFailure(kind: .other, message: error.localizedDescription)
        }
        switch error {
        case .guardrailViolation, .refusal:
            return OnDeviceAIFailure(
                kind: .declined,
                message: String(localized: "Apple Intelligence can't help with this prompt. Try it in another assistant instead.")
            )
        case .exceededContextWindowSize:
            return OnDeviceAIFailure(
                kind: .conversationTooLong,
                message: String(localized: "This conversation is too long for the on-device model. Start a new chat to keep going.")
            )
        case .unsupportedLanguageOrLocale:
            return OnDeviceAIFailure(
                kind: .declined,
                message: String(localized: "Apple Intelligence doesn't support this language yet.")
            )
        case .assetsUnavailable:
            return OnDeviceAIFailure(
                kind: .other,
                message: String(localized: "Apple Intelligence is still getting ready. Try again in a moment.")
            )
        case .rateLimited, .concurrentRequests:
            return OnDeviceAIFailure(
                kind: .other,
                message: String(localized: "Apple Intelligence is busy. Try again in a moment.")
            )
        default:
            return OnDeviceAIFailure(kind: .other, message: error.localizedDescription)
        }
    }
}
