import Dependencies
import SharingGRDB
import SwiftUI
import SwiftUINavigation

@Observable
@MainActor
class PromptListModel {
    var searchText = ""

    @ObservationIgnored
    @FetchAll(
        Prompt
            .all
            .order { $0.modifiedDate.desc() }
        , animation: .default) var prompts

    @ObservationIgnored
    @Dependency(\.defaultDatabase) var database

    @CasePathable
    enum Route {
        case showingAddPrompt
        case editingPrompt(Prompt)
        case showingDeleteAlert(Prompt)
    }

    var route: Route?

    var filteredPrompts: [Prompt] {
        var prompts = prompts

        if !searchText.isEmpty {
            prompts = searchPrompts(query: searchText)
        }

        return prompts
    }

    func searchPrompts(query: String) -> [Prompt] {
        guard !query.isEmpty else { return prompts }

        let lowercasedQuery = query.lowercased()
        return prompts.filter { prompt in
            prompt.act.lowercased().contains(lowercasedQuery) ||
                prompt.prompt.lowercased().contains(lowercasedQuery)
        }
    }

    func onFavorite(_ prompt: Prompt) {
        withErrorReporting {
            var updatedPrompt = prompt
            updatedPrompt.isFavorite.toggle()
            try database.write { db in
                try Prompt
                    .update(updatedPrompt)
                    .execute(db)
            }
        }
    }

    func onEdit(_ prompt: Prompt) {
        route = .editingPrompt(prompt)
    }

    func onDeleteRequest(_ prompt: Prompt) {
        route = .showingDeleteAlert(prompt)
    }

    func confirmDelete(_ prompt: Prompt) {
        withErrorReporting {
            try database.write { db in
                try Prompt.delete(prompt).execute(db)
            }
        }
    }
}

struct PromptListView: View {
    @State private var model = PromptListModel()

    var body: some View {
        NavigationView {
            VStack {
                List(model.filteredPrompts) { prompt in
                    NavigationLink(
                        destination: PromptDetailView(
                            model: PromptDetailModel(prompt: prompt)
                        )
                    ) {
                        PromptRowView(
                            prompt: prompt,
                            onFavorite: { model.onFavorite(prompt) }
                        )
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
            .searchable(text: $model.searchText)
            .navigationTitle("Prompts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        model.route = .showingAddPrompt
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: Binding($model.route.showingAddPrompt)) {
                PromptFormView(
                    model: PromptFormModel()
                )
            }
            .sheet(item: $model.route.editingPrompt, id: \.self) { prompt in
                PromptFormView(
                    model: PromptFormModel(
                        prompt: Prompt.Draft(prompt)
                    ) { _ in
                        model.route = nil
                    }
                )
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
                    Text("Are you sure you want to delete \(prompt.act)? This action cannot be undone.")
                }
            )
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)

            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

#Preview {
    PromptListView()
        .environmentObject(DataManager())
}
