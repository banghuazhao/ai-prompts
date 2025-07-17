import Dependencies
import SharingGRDB
import SwiftUI
import SwiftUINavigation

@Observable
@MainActor
class VibePromptListModel {
    var searchText = ""
    var showingAddPrompt = false

    @ObservationIgnored
    @FetchAll(VibePrompt.all, animation: .default) var vibePrompts

    @ObservationIgnored
    @Dependency(\.defaultDatabase) var database

    @CasePathable
    enum Route {
        case showingAddVibePrompt
        case editingPrompt(VibePrompt)
        case showingDeleteAlert(VibePrompt)
    }

    var route: Route?

    var filteredVibePrompts: [VibePrompt] {
        var vibePrompts = vibePrompts

        if !searchText.isEmpty {
            vibePrompts = searchVibePrompts(query: searchText)
        }

        return vibePrompts
    }

    func searchVibePrompts(query: String) -> [VibePrompt] {
        guard !query.isEmpty else { return vibePrompts }

        let lowercasedQuery = query.lowercased()
        return vibePrompts.filter { vibePrompt in
            vibePrompt.app.lowercased().contains(lowercasedQuery) ||
                vibePrompt.prompt.lowercased().contains(lowercasedQuery) ||
                vibePrompt.techstack.lowercased().contains(lowercasedQuery)
        }
    }

    func onFavorite(_ prompt: VibePrompt) {
        withErrorReporting {
            var updatedPrompt = prompt
            updatedPrompt.isFavorite.toggle()
            try database.write { db in
                try VibePrompt
                    .update(updatedPrompt)
                    .execute(db)
            }
        }
    }

    func onEdit(_ prompt: VibePrompt) {
        route = .editingPrompt(prompt)
    }

    func onDeleteRequest(_ prompt: VibePrompt) {
        route = .showingDeleteAlert(prompt)
    }

    func confirmDelete(_ prompt: VibePrompt) {
        withErrorReporting {
            try database.write { db in
                try VibePrompt.delete(prompt).execute(db)
            }
        }
    }
}

struct VibePromptListView: View {
    @State private var model = VibePromptListModel()

    var body: some View {
        NavigationView {
            VStack {
                List(model.filteredVibePrompts) { vibePrompt in
                    NavigationLink(destination: VibePromptDetailView(vibePrompt: vibePrompt)) {
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
            .searchable(text: $model.searchText)
            .navigationTitle("Vibe Prompts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        model.route = .showingAddVibePrompt
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: Binding($model.route.showingAddVibePrompt)) {
                AddVibePromptView()
            }
            .sheet(item: $model.route.editingPrompt, id: \.self) { prompt in
                EditVibePromptView(vibePrompt: prompt)
            }
            .alert(
                item: $model.route.showingDeleteAlert,
                title: { _ in
                    Text("Delete Prompt")
                },
                actions: { prompt in
                    Button("Delete", role: .destructive) {
                        model.confirmDelete(prompt)
                    }
                    Button("Cancel", role: .cancel) {
                    }
                },
                message: { prompt in
                    Text("Are you sure you want to delete \(prompt.app)? This action cannot be undone.")
                }
            )
        }
    }
}

struct AddVibePromptView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss

    @State private var app = ""
    @State private var prompt = ""
    @State private var contributor = ""
    @State private var techstack = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("App Details")) {
                    TextField("App Name", text: $app)
                    TextField("Contributor", text: $contributor)
                    TextField("Tech Stack (comma-separated)", text: $techstack)
                }

                Section(header: Text("Prompt")) {
                    TextEditor(text: $prompt)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Add Vibe Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let newVibePrompt = VibePrompt(
                            id: 0,
                            app: app,
                            prompt: prompt,
                            contributor: contributor,
                            techstack: techstack
                        )

                        dismiss()
                    }
                    .disabled(app.isEmpty || prompt.isEmpty)
                }
            }
        }
    }
}

#Preview {
    VibePromptListView()
        .environmentObject(DataManager())
}
