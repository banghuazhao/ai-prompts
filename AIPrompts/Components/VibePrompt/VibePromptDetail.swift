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
            VStack(alignment: .leading, spacing: 24) {
                // Header Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.vibePrompt.app)
                                .font(.title.bold())
                                .foregroundColor(.primary)
                                .lineLimit(3)
                                .minimumScaleFactor(0.5)
                            if !model.vibePrompt.contributor.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "person.circle")
                                    Link(model.vibePrompt.contributor, destination: model.vibePrompt.contributorGithubURL)
                                }
                                .font(.caption)
                                .foregroundColor(.accentColor)
                            }
                        }
                        Spacer()
                        Button(action: { model.onFavorite() }) {
                            Image(systemName: model.vibePrompt.isFavorite ? "heart.fill" : "heart")
                                .foregroundColor(model.vibePrompt.isFavorite ? .red : .gray)
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

                // Tech Stack Badges
                if !model.vibePrompt.techstack.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Tech Stack")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            ForEach(model.vibePrompt.techstackArray, id: \.self) { tech in
                                BadgeView(icon: nil, text: tech)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
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
                    Text(model.vibePrompt.prompt)
                        .font(.body)
                        .lineSpacing(5)
                        .foregroundColor(.primary)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.systemGray6))
                        )
                }
                .padding(.horizontal, 2)

                // Action Buttons Row (removed)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { model.onEdit() }) {
                    Image(systemName: "pencil")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { model.onDeleteRequest() }) {
                    Image(systemName: "trash")
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
