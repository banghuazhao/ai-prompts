import SharingGRDB
import SwiftUI
import SwiftUINavigation

@Observable
@MainActor
class FavoritesViewModel {
    var selectedTab = 0

    @ObservationIgnored
    @FetchAll(
        Prompt.all
            .where(\.isFavorite)
            .order { $0.modifiedDate.desc() }
        , animation: .default) var favoritePrompts

    @ObservationIgnored
    @FetchAll(
        VibePrompt.all
            .where(\.isFavorite)
            .order { $0.modifiedDate.desc() }
        , animation: .default) var favoriteVibePrompts

    @ObservationIgnored
    @Dependency(\.defaultDatabase) var database

    @CasePathable
    enum Route {
        case editingPrompt(Prompt)
        case editingVibePrompt(VibePrompt)
        case showingDeletePromptAlert(Prompt)
        case showingDeleteVibePromptAlert(VibePrompt)
    }

    var route: Route?

    // Prompt actions
    func onEdit(_ prompt: Prompt) {
        route = .editingPrompt(prompt)
    }

    func onDeleteRequest(_ prompt: Prompt) {
        route = .showingDeletePromptAlert(prompt)
    }

    func confirmDelete(_ prompt: Prompt) {
        withErrorReporting {
            try database.write { db in
                try Prompt.delete(prompt).execute(db)
            }
        }
    }

    func onUpdate(_ newPrompt: Prompt) {
        withErrorReporting {
            try database.write { db in
                try Prompt.update(newPrompt).execute(db)
            }
        }
    }

    func onFavorite(_ prompt: Prompt) {
        withErrorReporting {
            var updatedPrompt = prompt
            updatedPrompt.isFavorite.toggle()
            try database.write { db in
                try Prompt.update(updatedPrompt).execute(db)
            }
        }
    }

    // VibePrompt actions
    func onEdit(_ vibePrompt: VibePrompt) {
        route = .editingVibePrompt(vibePrompt)
    }

    func onDeleteRequest(_ vibePrompt: VibePrompt) {
        route = .showingDeleteVibePromptAlert(vibePrompt)
    }

    func confirmDelete(_ vibePrompt: VibePrompt) {
        withErrorReporting {
            try database.write { db in
                try VibePrompt.delete(vibePrompt).execute(db)
            }
        }
    }

    func onUpdate(_ newVibePrompt: VibePrompt) {
        withErrorReporting {
            try database.write { db in
                try VibePrompt.update(newVibePrompt).execute(db)
            }
        }
    }

    func onFavorite(_ vibePrompt: VibePrompt) {
        withErrorReporting {
            var updatedPrompt = vibePrompt
            updatedPrompt.isFavorite.toggle()
            try database.write { db in
                try VibePrompt.update(updatedPrompt).execute(db)
            }
        }
    }
}

struct FavoritesView: View {
    @State private var model = FavoritesViewModel()

    var body: some View {
        NavigationView {
            VStack {
                // Tab Picker
                Picker("Favorites", selection: $model.selectedTab) {
                    Text("Prompts (\(model.favoritePrompts.count))").tag(0)
                    Text("Vibe Prompts (\(model.favoriteVibePrompts.count))").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                // Content based on selected tab
                if model.selectedTab == 0 {
                    if model.favoritePrompts.isEmpty {
                        EmptyFavoritesView(
                            title: "No Favorite Prompts",
                            message: "Prompts you favorite will appear here",
                            systemImage: "heart"
                        )
                    } else {
                        List(model.favoritePrompts) { prompt in
                            NavigationLink(
                                destination: PromptDetailView(
                                    model: PromptDetailModel(prompt: prompt)
                                )
                            ) {
                                PromptRowView(prompt: prompt) {
                                    model.onFavorite(prompt)
                                }
                                .contextMenu {
                                    Button(action: { model.onEdit(prompt) }) {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(action: { model.onFavorite(prompt) }) {
                                        Label(prompt.isFavorite ? "Unfavorite" : "Favorite", systemImage: prompt.isFavorite ? "heart.slash" : "heart")
                                    }
                                    Button(role: .destructive, action: { model.onDeleteRequest(prompt) }) {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                } else {
                    if model.favoriteVibePrompts.isEmpty {
                        EmptyFavoritesView(
                            title: "No Favorite Vibe Prompts",
                            message: "Vibe prompts you favorite will appear here",
                            systemImage: "sparkles"
                        )
                    } else {
                        List(model.favoriteVibePrompts) { vibePrompt in
                            NavigationLink(
                                destination: VibePromptDetailView(
                                    model: .init(vibePrompt: vibePrompt)
                                )
                            ) {
                                VibePromptRowView(vibePrompt: vibePrompt) {
                                    model.onFavorite(vibePrompt)
                                }
                                .contextMenu {
                                    Button(action: { model.onEdit(vibePrompt) }) {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(action: { model.onFavorite(vibePrompt) }) {
                                        Label(vibePrompt.isFavorite ? "Unfavorite" : "Favorite", systemImage: vibePrompt.isFavorite ? "heart.slash" : "heart")
                                    }
                                    Button(role: .destructive, action: { model.onDeleteRequest(vibePrompt) }) {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.large)
            // Prompt sheets/alerts
            .sheet(item: $model.route.editingPrompt, id: \.self) { prompt in
                PromptFormView(
                    model: PromptFormModel(prompt: Prompt.Draft(prompt)) { _ in
                        model.route = nil
                    }
                )
            }
            .sheet(item: $model.route.editingVibePrompt, id: \.self) { vibePrompt in
                VibePromptFormView(
                    model: VibePromptFormModel(prompt: VibePrompt.Draft(vibePrompt)) { _ in
                        model.route = nil
                    }
                )
            }
            .alert(
                item: $model.route.showingDeletePromptAlert,
                title: { _ in Text("Delete Prompt") },
                actions: { prompt in
                    Button("Delete", role: .destructive) {
                        model.confirmDelete(prompt)
                    }
                    Button("Cancel", role: .cancel) {}
                },
                message: { prompt in
                    Text("Are you sure you want to delete \(prompt.act)? This action cannot be undone.")
                }
            )
            .alert(
                item: $model.route.showingDeleteVibePromptAlert,
                title: { _ in Text("Delete Vibe Prompt") },
                actions: { vibePrompt in
                    Button("Delete", role: .destructive) {
                        model.confirmDelete(vibePrompt)
                    }
                    Button("Cancel", role: .cancel) {}
                },
                message: { vibePrompt in
                    Text("Are you sure you want to delete \(vibePrompt.app)? This action cannot be undone.")
                }
            )
        }
    }
}

struct EmptyFavoritesView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: systemImage)
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.05))
    }
}
