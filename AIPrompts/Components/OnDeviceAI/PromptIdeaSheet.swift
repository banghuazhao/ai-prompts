//
// Created by Banghua Zhao on 27/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI

/// Asks what a new prompt should help with, then has Apple Intelligence write it.
///
/// `generate` gets the topic (empty for a surprise) and should hand the result on, for example
/// by opening the add form once this sheet is gone. The sheet closes when it returns, and shows
/// the error when it throws.
struct PromptIdeaSheet: View {
    let title: LocalizedStringKey
    let placeholder: LocalizedStringKey
    /// Tappable topics that fill the field.
    let examples: [String]
    let generate: (String) async throws -> Void

    @State private var topic = ""
    @State private var isGenerating = false
    @State private var failure: OnDeviceAIFailure?
    @FocusState private var isTopicFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(placeholder, text: $topic, axis: .vertical)
                        .lineLimit(1 ... 4)
                        .focused($isTopicFocused)
                        .disabled(isGenerating)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(examples, id: \.self) { example in
                                Button {
                                    Haptics.shared.vibrateIfEnabled()
                                    topic = example
                                } label: {
                                    Text(example)
                                        .font(.footnote)
                                        .lineLimit(1)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.purple.opacity(0.12), in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .disabled(isGenerating)
                            }
                        }
                    }
                    .scrollClipDisabled()
                } header: {
                    Text("What should it help with?")
                } footer: {
                    Text("Leave it empty for a surprise.")
                }

                Section {
                    Button {
                        Haptics.shared.vibrateIfEnabled()
                        start()
                    } label: {
                        HStack(spacing: 8) {
                            if isGenerating {
                                ProgressView()
                                Text("Writing…")
                            } else {
                                Image(systemName: "sparkles")
                                Text("Write It")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isGenerating)
                    if let failure {
                        Text(failure.message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Apple Intelligence writes it on your device. You can edit it before saving.")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isTopicFocused = true
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(isGenerating)
    }

    private func start() {
        let request = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        isTopicFocused = false
        isGenerating = true
        failure = nil
        Task {
            do {
                try await generate(request)
                dismiss()
            } catch {
                if #available(iOS 26.0, *) {
                    failure = OnDeviceAIFailure(error)
                } else {
                    failure = OnDeviceAIFailure(kind: .other, message: error.localizedDescription)
                }
            }
            isGenerating = false
        }
    }
}
