import Dependencies
import SwiftUI
import SwiftUINavigation

@Observable
@MainActor
class PromptDetailModel {
    @ObservationIgnored
    @Dependency(\.defaultDatabase) var database

    var prompt: Prompt

    @CasePathable
    enum Route {
        case editingPrompt
        case showingDeleteAlert(Prompt)
    }

    var route: Route?

    var copiedToClipboard = false

    init(prompt: Prompt) {
        self.prompt = prompt
    }

    func onCopy() {
        UIPasteboard.general.string = prompt.prompt
        copiedToClipboard = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.copiedToClipboard = false
        }
    }

    func onFavorite() {
        withErrorReporting {
            var updatedPrompt = prompt
            updatedPrompt.isFavorite.toggle()
            try database.write { db in
                try Prompt.update(updatedPrompt).execute(db)
            }
            prompt = updatedPrompt
        }
    }

    func onEdit() {
        route = .editingPrompt
    }

    func onDeleteRequest() {
        route = .showingDeleteAlert(prompt)
    }

    func confirmDelete(action: () -> Void) {
        withErrorReporting {
            try database.write { db in
                try Prompt.delete(prompt).execute(db)
            }
        }
        action()
    }

    func onUpdate(_ newPrompt: Prompt) {
        withAnimation {
            route = nil
            prompt = newPrompt
        }
    }
}

struct PromptDetailView: View {
    @State var model: PromptDetailModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.prompt.act)
                                .font(.title.bold())
                                .foregroundColor(.primary)
                                .lineLimit(3)
                                .minimumScaleFactor(0.5)
                            if model.prompt.forDevs {
                                BadgeView(icon: "laptopcomputer", text: "For Developers")
                            }
                        }
                        Spacer()
                        Button(action: { model.onFavorite() }) {
                            Image(systemName: model.prompt.isFavorite ? "heart.fill" : "heart")
                                .foregroundColor(model.prompt.isFavorite ? .red : .gray)
                                .font(.title2)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
                )
                
                // Quick Launch LLMs
                VStack(alignment: .leading, spacing: 10) {
                    Text("Quick Launch")
                        .font(AppFont.headline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 2)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppSpacing.small) {
                            LLMQuickLaunchButton(
                                icon: "message.fill",
                                label: "ChatGPT",
                                background: .chatGPT,
                                foreground: .white,
                                url: URL(string: "https://chatgpt.com/?prompt=\(model.prompt.prompt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
                            )
                            LLMQuickLaunchButton(
                                icon: "bolt.fill",
                                label: "Grok",
                                background: .grok,
                                foreground: .white,
                                url: URL(string: "https://grok.x.ai/?q=\(model.prompt.prompt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
                            )
                            LLMQuickLaunchButton(
                                icon: "sun.max.fill",
                                label: "Claude",
                                background: .claude,
                                foreground: .black,
                                url: URL(string: "https://claude.ai/chat?prompt=\(model.prompt.prompt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
                            )
                            LLMQuickLaunchButton(
                                icon: "questionmark.circle.fill",
                                label: "Perplexity",
                                background: .perplexity,
                                foreground: .white,
                                url: URL(string: "https://www.perplexity.ai/?q=\(model.prompt.prompt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
                            )
                            LLMQuickLaunchButton(
                                icon: "sparkles",
                                label: "Gemini",
                                background: .gemini,
                                foreground: .white,
                                url: URL(string: "https://gemini.google.com/app?prompt=\(model.prompt.prompt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
                            )
                        }
                        .padding(.vertical, 2)
                    }
                }

                // Prompt Content Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Prompt")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: { model.onCopy() }) {
                            ZStack {
                                HStack {
                                    Image(systemName: "doc.on.doc")
                                        .opacity(model.copiedToClipboard ? 0 : 1)
                                    Text("Copy")
                                        .opacity(model.copiedToClipboard ? 0 : 1)
                                }
                                HStack {
                                    Image(systemName: "checkmark")
                                        .opacity(model.copiedToClipboard ? 1 : 0)
                                    Text("Copied!")
                                        .opacity(model.copiedToClipboard ? 1 : 0)
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                        .disabled(model.copiedToClipboard)
                    }
                    Text(model.prompt.prompt)
                        .font(.body)
                        .lineSpacing(5)
                        .foregroundColor(.primary)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Haptics.shared.vibrateIfEnabled()
                    model.onDeleteRequest()
                }) {
                    Image(systemName: "trash")
                }
                .tint(.red)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                ShareLink(item: "\(model.prompt.act)\n\n\(model.prompt.prompt)") {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Haptics.shared.vibrateIfEnabled()
                    model.onEdit()
                }) {
                    Image(systemName: "pencil")
                }
            }
        }
        .sheet(isPresented: Binding($model.route.editingPrompt)) {
            PromptFormView(
                model: PromptFormModel(
                    prompt: Prompt.Draft(model.prompt)
                ) { newPrompt in
                    model.onUpdate(newPrompt)
                }
            )
        }
        .alert(
            item: $model.route.showingDeleteAlert,
            title: { _ in
                Text("Delete Prompt")
            },
            actions: { _ in
                Button("Delete", role: .destructive) {
                    Haptics.shared.vibrateIfEnabled()
                    model.confirmDelete {
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {
                    Haptics.shared.vibrateIfEnabled()
                }
            },
            message: { prompt in
                Text("Are you sure you want to delete \(prompt.act)? This action cannot be undone.")
            }
        )
    }
}

#Preview {
    NavigationView {
        PromptDetailView(
            model: PromptDetailModel(
                prompt: Prompt(id: 1, act: "Test Prompt", prompt: "This is a test prompt content.", forDevs: true)
            )
        )
    }
}
