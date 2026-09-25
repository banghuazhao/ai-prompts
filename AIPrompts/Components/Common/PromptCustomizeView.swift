import SwiftUI

/// Lets the user fill in a prompt's variables, preview the result, then copy or launch it.
struct PromptCustomizeView: View {
    let title: String
    let template: PromptTemplate

    @State private var values: [String: String]
    @State private var copied = false
    @Environment(\.dismiss) private var dismiss

    init(title: String, prompt: String) {
        self.title = title
        let template = PromptTemplate(prompt)
        self.template = template
        _values = State(initialValue: template.defaultValues)
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
                        }
                        .padding(.vertical, 2)
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

                    LLMQuickLaunchSection(prompt: renderedPrompt)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
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

    private func binding(for id: String) -> Binding<String> {
        Binding(
            get: { values[id, default: ""] },
            set: { values[id] = $0 }
        )
    }

    private func onCopy() {
        UIPasteboard.general.string = renderedPrompt
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
