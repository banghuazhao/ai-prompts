import SwiftUI

/// Lets the user fill in a prompt's variables, preview the result, then copy or launch it.
struct PromptCustomizeView: View {
    let title: String
    let prompt: String
    let template: PromptTemplate

    @State private var values: [String: String]
    @State private var copied = false
    @State private var isRunningOnDevice = false
    @State private var suggestions: [String: [String]] = [:]
    @State private var isSuggesting = false
    @State private var suggestionFailure: OnDeviceAIFailure?
    @Environment(\.dismiss) private var dismiss

    init(title: String, prompt: String) {
        self.title = title
        self.prompt = prompt
        let template = PromptTemplate(prompt)
        self.template = template
        _values = State(initialValue: PromptVariableMemory.initialValues(for: template))
    }

    private var renderedPrompt: String {
        template.render(values)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(template.variables) { variable in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(variable.label)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.secondary)
                            TextField(
                                variable.defaultValue.isEmpty ? variable.label : variable.defaultValue,
                                text: binding(for: variable.id),
                                axis: .vertical
                            )
                            .lineLimit(1 ... 6)
                            if let options = suggestions[variable.id], !options.isEmpty {
                                SuggestionChips(options: options) { option in
                                    Haptics.shared.vibrateIfEnabled()
                                    values[variable.id] = option
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    if OnDeviceAI.status == .available {
                        suggestIdeasRow
                    }
                } header: {
                    Text("Fill in the blanks")
                } footer: {
                    Text("Leave a field empty to keep the original text.")
                }

                Section("Preview") {
                    Text(renderedPrompt)
                        .font(.callout)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                }

                Section {
                    Button {
                        Haptics.shared.vibrateIfEnabled()
                        onCopy()
                    } label: {
                        Label(copied ? "Copied!" : "Copy Prompt", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .glassButtonStyle(prominent: true)
                    .controlSize(.large)
                    .tint(copied ? Color.green : Color.accentColor)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                    if OnDeviceAI.isSupported {
                        Button {
                            Haptics.shared.vibrateIfEnabled()
                            PromptVariableMemory.save(values, for: template)
                            isRunningOnDevice = true
                        } label: {
                            Label("Run on Device", systemImage: "sparkles")
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                        }
                        .glassButtonStyle(prominent: true)
                        .controlSize(.large)
                        .tint(.purple)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
                    }

                    LLMQuickLaunchSection(prompt: renderedPrompt)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear {
                PromptVariableMemory.save(values, for: template)
            }
            .sheet(isPresented: $isRunningOnDevice) {
                PromptRunSheet(title: title, prompt: renderedPrompt)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        Haptics.shared.vibrateIfEnabled()
                        withAnimation {
                            values = template.defaultValues
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Haptics.shared.vibrateIfEnabled()
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var suggestIdeasRow: some View {
        if isSuggesting {
            Label {
                Text("Thinking of ideas…")
                    .foregroundStyle(.secondary)
            } icon: {
                ProgressView()
            }
        } else {
            Button {
                Haptics.shared.vibrateIfEnabled()
                suggestIdeas()
            } label: {
                Label(suggestions.isEmpty ? "Suggest Ideas" : "More Ideas", systemImage: "sparkles")
            }
            if let suggestionFailure {
                Text(suggestionFailure.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func suggestIdeas() {
        guard #available(iOS 26.0, *) else { return }
        isSuggesting = true
        suggestionFailure = nil
        Task {
            do {
                let result = try await PromptAssistant.suggestValues(for: template, text: prompt)
                withAnimation {
                    suggestions = result
                }
            } catch {
                suggestionFailure = OnDeviceAIFailure(error)
            }
            isSuggesting = false
        }
    }

    private func binding(for id: String) -> Binding<String> {
        Binding(
            get: { values[id, default: ""] },
            set: { values[id] = $0 }
        )
    }

    private func onCopy() {
        PromptActions.copy(renderedPrompt)
        withAnimation {
            copied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copied = false
            }
        }
    }
}

/// Tappable values suggested by the on-device model for one blank.
private struct SuggestionChips: View {
    let options: [String]
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    Button {
                        onSelect(option)
                    } label: {
                        Text(option)
                            .font(.footnote)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.purple.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollClipDisabled()
    }
}

/// Call-to-action card shown on a detail page when the prompt has fill-in-the-blank variables.
struct PromptCustomizeCard: View {
    let variableCount: Int
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.shared.vibrateIfEnabled()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                    .foregroundColor(.accentColor)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Customize & Use")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(variableCount == 1 ? "Fill in 1 blank before copying or launching" : "Fill in \(variableCount) blanks before copying or launching")
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

#Preview {
    PromptCustomizeView(
        title: "Storyteller",
        prompt: "I want you to act as a storyteller for {{audience}}. My first request is \"I need an interesting story on perseverance.\""
    )
}
