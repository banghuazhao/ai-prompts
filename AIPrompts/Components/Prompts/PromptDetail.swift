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
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(model.prompt.act)
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Spacer()

                        Button(action: {
                            model.onFavorite()
                        }) {
                            Image(systemName: model.prompt.isFavorite ? "heart.fill" : "heart")
                                .foregroundColor(model.prompt.isFavorite ? .red : .gray)
                                .font(.title2)
                        }
                    }

                    if model.prompt.forDevs {
                        BadgeView(icon: "laptopcomputer", text: "For Developers")
                    }
                }

                Divider()

                // Prompt Content
                VStack(alignment: .leading, spacing: 15) {
                    Text("Prompt")
                        .font(.headline)

                    Text(model.prompt.prompt)
                        .font(.body)
                        .lineSpacing(4)
                }

                // Action Buttons
                VStack(spacing: 10) {
                    Button(action: {
                        model.onCopy()
                    }) {
                        HStack {
                            Image(systemName: model.copiedToClipboard ? "checkmark" : "doc.on.doc")
                            Text(model.copiedToClipboard ? "Copied!" : "Copy Prompt")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    model.onDeleteRequest()
                }) {
                    Image(systemName: "trash")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
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
                    model.confirmDelete {
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {
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
