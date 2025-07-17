import Dependencies
import SharingGRDB
import SwiftUI
import SwiftUINavigation

@Observable
@MainActor
class VibePromptDetailModel {
    @ObservationIgnored
    @Dependency(\.defaultDatabase) var database

    var vibePrompt: VibePrompt

    @CasePathable
    enum Route {
        case editingPrompt
        case showingDeleteAlert(VibePrompt)
    }

    var route: Route?
    var copiedToClipboard = false

    init(vibePrompt: VibePrompt) {
        self.vibePrompt = vibePrompt
    }

    func onCopy() {
        UIPasteboard.general.string = vibePrompt.prompt
        copiedToClipboard = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.copiedToClipboard = false
        }
    }

    func onFavorite() {
        withErrorReporting {
            var updatedPrompt = vibePrompt
            updatedPrompt.isFavorite.toggle()
            try database.write { db in
                try VibePrompt.update(updatedPrompt).execute(db)
            }
            vibePrompt = updatedPrompt
        }
    }

    func onEdit() {
        route = .editingPrompt
    }

    func onDeleteRequest() {
        route = .showingDeleteAlert(vibePrompt)
    }

    func confirmDelete(action: () -> Void) {
        withErrorReporting {
            try database.write { db in
                try VibePrompt.delete(vibePrompt).execute(db)
            }
        }
        action()
    }

    func onUpdate(_ newPrompt: VibePrompt) {
        withAnimation {
            route = nil
            vibePrompt = newPrompt
        }
    }
}

struct VibePromptDetailView: View {
    @State var model: VibePromptDetailModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(model.vibePrompt.app)
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Spacer()

                        Button(action: {
                            model.onFavorite()
                        }) {
                            Image(systemName: model.vibePrompt.isFavorite ? "heart.fill" : "heart")
                                .foregroundColor(model.vibePrompt.isFavorite ? .red : .gray)
                                .font(.title2)
                        }
                    }

                    if !model.vibePrompt.contributor.isEmpty {
                        HStack {
                            Image(systemName: "person.circle")
                            Link(model.vibePrompt.contributor, destination: model.vibePrompt.contributorGithubURL)
                        }
                        .foregroundColor(.accentColor)
                    }
                }

                Divider()

                // Tech Stack as badges
                if !model.vibePrompt.techstack.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Tech Stack")
                            .font(.headline)
                        HStack(spacing: 8) {
                            ForEach(model.vibePrompt.techstackArray, id: \.self) { tech in
                                Text(tech)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.systemGray5))
                                    .foregroundColor(.primary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }

                Divider()

                // Prompt Content
                VStack(alignment: .leading, spacing: 15) {
                    Text("Prompt")
                        .font(.headline)

                    Text(model.vibePrompt.prompt)
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
            VibePromptFormView(
                model: VibePromptFormModel(
                    prompt: VibePrompt.Draft(model.vibePrompt)
                ) { newPrompt in
                    model.onUpdate(newPrompt)
                }
            )
        }
        .alert(
            item: $model.route.showingDeleteAlert,
            title: { _ in
                Text("Delete Vibe Prompt")
            },
            actions: { _ in
                Button("Delete", role: .destructive) {
                    model.confirmDelete {
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            },
            message: { prompt in
                Text("Are you sure you want to delete \(prompt.app)? This action cannot be undone.")
            }
        )
    }
}

#Preview {
    NavigationView {
        VibePromptDetailView(
            model: VibePromptDetailModel(
                vibePrompt: VibePrompt(id: 0, app: "Test App", prompt: "This is a test vibe prompt content.", contributor: "Test Contributor", techstack: "Swift, SwiftUI, iOS")
            )
        )
    }
}
