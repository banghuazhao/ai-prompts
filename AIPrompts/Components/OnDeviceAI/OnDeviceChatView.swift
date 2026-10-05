//
// Created by Banghua Zhao on 04/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import Dependencies
import SharingGRDB
import SwiftUI

/// Sheet that runs a prompt with the on-device model, or explains why it can't.
struct PromptRunSheet: View {
    let title: String
    let prompt: String

    var body: some View {
        if #available(iOS 26.0, *), OnDeviceAI.status == .available {
            OnDeviceChatView(title: title, prompt: prompt)
        } else {
            NavigationStack {
                OnDeviceAIUnavailableView(status: OnDeviceAI.status)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            DismissButton()
                        }
                    }
            }
        }
    }
}

extension PromptTemplate {
    /// The prompt ready to run as is, or nil while a blank still needs the user's input.
    var runnablePrompt: String? {
        let values = PromptVariableMemory.initialValues(for: self)
        let isFilled = variables.allSatisfy {
            !(values[$0.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return isFilled ? render(values) : nil
    }
}

@available(iOS 26.0, *)
struct OnDeviceChatView: View {
    let title: String
    let prompt: String

    @State private var chat = OnDeviceChat()
    @State private var followUp = ""
    @State private var savedChatID: AIChat.ID?
    @State private var createdDate = Date()
    @Dependency(\.defaultDatabase) private var database

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(chat.messages) { message in
                        AIMessageView(
                            message: message,
                            isStreaming: chat.isResponding && message.id == chat.messages.last?.id
                        )
                    }
                    if let failure = chat.failure {
                        AIFailureView(
                            failure: failure,
                            lastPrompt: chat.messages.last { $0.role == .user }?.text ?? prompt,
                            onRetry: { chat.retry() },
                            onStartOver: startOver
                        )
                    }
                }
                .padding()
            }
            .defaultScrollAnchor(.bottom, for: .sizeChanges)
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                composer
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    DismissButton()
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Start Over", systemImage: "arrow.counterclockwise") {
                            Haptics.shared.vibrateIfEnabled()
                            startOver()
                        }
                        ShareLink(item: AIMessage.transcript(chat.messages)) {
                            Label("Share Conversation", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .disabled(chat.isResponding)
                }
            }
            .task {
                if chat.messages.isEmpty {
                    chat.send(prompt)
                }
            }
            .onChange(of: chat.isResponding) { _, isResponding in
                if !isResponding {
                    save()
                }
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Ask a follow-up", text: $followUp, axis: .vertical)
                .lineLimit(1 ... 5)
                .padding(.vertical, 6)
                .onSubmit(sendFollowUp)
            if chat.isResponding {
                Button {
                    Haptics.shared.vibrateIfEnabled()
                    chat.stop()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.title)
                }
                .accessibilityLabel("Stop")
            } else {
                Button {
                    Haptics.shared.vibrateIfEnabled()
                    sendFollowUp()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                }
                .disabled(followUp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Send")
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.vertical, 4)
        .glassCard(cornerRadius: 24, interactive: true, fallback: Color(.systemBackground))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func sendFollowUp() {
        guard !chat.isResponding else { return }
        chat.send(followUp)
        followUp = ""
    }

    private func startOver() {
        chat.startOver()
        savedChatID = nil
        createdDate = Date()
        chat.send(prompt)
    }

    private func save() {
        let messages = chat.messages
        guard messages.contains(where: { $0.role == .assistant }) else { return }
        withErrorReporting {
            savedChatID = try database.write { db in
                try AIChat
                    .upsert {
                        AIChat.Draft(
                            id: savedChatID,
                            title: title,
                            messagesJSON: AIChat.encode(messages),
                            createdDate: createdDate,
                            modifiedDate: Date()
                        )
                    }
                    .returning { $0 }
                    .fetchOne(db)?
                    .id
            }
        }
        PromptActions.ranOnDevice()
    }
}

// MARK: - Messages

extension AIMessage {
    /// Plain text version of a conversation for sharing.
    static func transcript(_ messages: [AIMessage]) -> String {
        messages
            .map { $0.role == .user ? "› \($0.text)" : $0.text }
            .joined(separator: "\n\n")
    }
}

struct AIMessageView: View {
    let message: AIMessage
    var isStreaming = false

    @State private var isExpanded = false
    @State private var copied = false

    var body: some View {
        switch message.role {
        case .user:
            userMessage
        case .assistant:
            assistantMessage
        }
    }

    private var userMessage: some View {
        HStack {
            Spacer(minLength: 40)
            Text(message.text)
                .font(.callout)
                .lineLimit(isExpanded ? nil : 6)
                .padding(12)
                .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .onTapGesture {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }
        }
    }

    private var assistantMessage: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("On-Device AI", systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.purple)
            if message.text.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Thinking…")
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(Self.markdown(message.text))
                    .font(.body)
                    .lineSpacing(4)
                    .textSelection(.enabled)
            }
            if !isStreaming, !message.text.isEmpty {
                HStack(spacing: 16) {
                    Button {
                        Haptics.shared.vibrateIfEnabled()
                        onCopy()
                    } label: {
                        Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    ShareLink(item: message.text) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .simultaneousGesture(TapGesture().onEnded { PromptActions.share() })
                }
                .font(.footnote)
                .labelStyle(.iconOnly)
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func onCopy() {
        PromptActions.copy(message.text)
        withAnimation {
            copied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copied = false
            }
        }
    }

    private static func markdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

private struct AIFailureView: View {
    let failure: OnDeviceAIFailure
    let lastPrompt: String
    let onRetry: () -> Void
    let onStartOver: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(failure.message, systemImage: "exclamationmark.bubble")
                .font(.callout)
                .foregroundStyle(.secondary)
            switch failure.kind {
            case .declined:
                LLMQuickLaunchSection(prompt: lastPrompt)
            case .conversationTooLong:
                Button("Start New Chat", systemImage: "arrow.counterclockwise") {
                    Haptics.shared.vibrateIfEnabled()
                    onStartOver()
                }
                .glassButtonStyle(prominent: true)
            case .other:
                Button("Try Again", systemImage: "arrow.clockwise") {
                    Haptics.shared.vibrateIfEnabled()
                    onRetry()
                }
                .glassButtonStyle()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Unavailable

struct OnDeviceAIUnavailableView: View {
    let status: OnDeviceAI.Status

    var body: some View {
        ContentUnavailableView {
            Label("On-Device AI Unavailable", systemImage: "sparkles")
        } description: {
            Text(description)
        }
    }

    private var description: LocalizedStringKey {
        switch status {
        case .notEnabled:
            "Turn on Apple Intelligence in Settings › Apple Intelligence & Siri to run prompts for free, right on your iPhone."
        case .notReady:
            "Apple Intelligence is still downloading. Try again once it's ready."
        case .unsupportedLanguage:
            "Apple Intelligence doesn't support your current language yet."
        case .available, .unsupported:
            "Running prompts on device needs an iPhone that supports Apple Intelligence."
        }
    }
}

private struct DismissButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button("Done") {
            Haptics.shared.vibrateIfEnabled()
            dismiss()
        }
    }
}

// MARK: - Entry point

/// Call-to-action card that runs a prompt with the on-device model.
struct RunOnDeviceCard: View {
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.shared.vibrateIfEnabled()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        LinearGradient(colors: [.purple, .pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Circle()
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Run on Device")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Free and private with Apple Intelligence")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .glassCard(interactive: true, fallback: Color(.systemBackground))
        }
        .buttonStyle(.plain)
    }
}
