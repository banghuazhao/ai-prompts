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
        case customizing
        case showingDeleteAlert(VibePrompt)
    }

    var route: Route?
    var copiedToClipboard = false

    init(vibePrompt: VibePrompt) {
        self.vibePrompt = vibePrompt
    }

    func onCopy() {
        PromptActions.copy(vibePrompt.prompt)
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
            PromptActions.favoriteToggled(isFavorite: updatedPrompt.isFavorite)
        }
    }

    var template: PromptTemplate {
        PromptTemplate(vibePrompt.prompt)
    }

    func onCustomize() {
        route = .customizing
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
                                .glassCircle(interactive: true, fallback: Color(.systemGray6))
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
                }

                // Fill-in-the-blank variables
                let template = model.template
                if template.hasVariables {
                    PromptCustomizeCard(variableCount: template.variables.count) {
                        model.onCustomize()
                    }
                }

                // Quick Launch LLMs
                LLMQuickLaunchSection(prompt: model.vibePrompt.prompt)

                // Prompt Content Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Prompt")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: {
                            Haptics.shared.vibrateIfEnabled()
                            model.onCopy()
                        }) {
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
                        .glassButtonStyle()
                        .tint(.blue)
                        .disabled(model.copiedToClipboard)
                    }
                    Text(model.vibePrompt.prompt)
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
                ShareLink(item: "\(model.vibePrompt.app)\n\n\(model.vibePrompt.prompt)") {
                    Image(systemName: "square.and.arrow.up")
                }
                .simultaneousGesture(TapGesture().onEnded { PromptActions.share() })
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
        .sheet(isPresented: Binding($model.route.customizing)) {
            PromptCustomizeView(title: model.vibePrompt.app, prompt: model.vibePrompt.prompt)
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
                Text("Are you sure you want to delete \(prompt.app)? This action cannot be undone.")
            }
        )
    }
}

#Preview {
    NavigationStack {
        VibePromptDetailView(
            model: VibePromptDetailModel(
                vibePrompt: VibePrompt(id: 0, app: "Test App", prompt: "This is a test vibe prompt content.", contributor: "Test Contributor", techstack: "Swift, SwiftUI, iOS")
            )
        )
    }
}
