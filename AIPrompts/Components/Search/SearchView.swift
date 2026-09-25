import SharingGRDB
import SwiftUI

/// Searches prompts and vibe prompts together. Shown as the search tab on iOS 26.
struct SearchView: View {
    @FetchAll(Prompt.all, animation: .default) private var prompts
    @FetchAll(VibePrompt.all, animation: .default) private var vibePrompts
    @Dependency(\.defaultDatabase) private var database

    @State private var query = ""

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var matchingPrompts: [Prompt] {
        guard !trimmedQuery.isEmpty else { return [] }
        return prompts
            .filter { $0.act.localizedCaseInsensitiveContains(trimmedQuery) || $0.prompt.localizedCaseInsensitiveContains(trimmedQuery) }
            .sorted { $0.act.localizedCaseInsensitiveCompare($1.act) == .orderedAscending }
    }

    private var matchingVibePrompts: [VibePrompt] {
        guard !trimmedQuery.isEmpty else { return [] }
        return vibePrompts
            .filter {
                $0.app.localizedCaseInsensitiveContains(trimmedQuery) ||
                    $0.prompt.localizedCaseInsensitiveContains(trimmedQuery) ||
                    $0.techstack.localizedCaseInsensitiveContains(trimmedQuery)
            }
            .sorted { $0.app.localizedCaseInsensitiveCompare($1.app) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            let promptResults = matchingPrompts
            let vibePromptResults = matchingVibePrompts
            List {
                if !promptResults.isEmpty {
                    Section("Prompts") {
                        ForEach(promptResults) { prompt in
                            NavigationLink(destination: PromptDetailView(model: PromptDetailModel(prompt: prompt))) {
                                PromptRowView(prompt: prompt) {
                                    toggleFavorite(prompt)
                                }
                            }
                        }
                    }
                }
                if !vibePromptResults.isEmpty {
                    Section("Vibe Prompts") {
                        ForEach(vibePromptResults) { vibePrompt in
                            NavigationLink(destination: VibePromptDetailView(model: VibePromptDetailModel(vibePrompt: vibePrompt))) {
                                VibePromptRowView(vibePrompt: vibePrompt) {
                                    toggleFavorite(vibePrompt)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollDismissesKeyboard(.immediately)
            .overlay {
                if trimmedQuery.isEmpty {
                    ContentUnavailableView(
                        "Search Everything",
                        systemImage: "magnifyingglass",
                        description: Text("Find prompts and vibe prompts by title, text, or tech stack.")
                    )
                } else if promptResults.isEmpty && vibePromptResults.isEmpty {
                    ContentUnavailableView.search(text: trimmedQuery)
                }
            }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Prompts and vibe prompts")
        }
    }

    private func toggleFavorite(_ prompt: Prompt) {
        withErrorReporting {
            var updated = prompt
            updated.isFavorite.toggle()
            PromptActions.favoriteToggled(isFavorite: updated.isFavorite)
            try database.write { db in
                try Prompt.update(updated).execute(db)
            }
        }
    }

    private func toggleFavorite(_ vibePrompt: VibePrompt) {
        withErrorReporting {
            var updated = vibePrompt
            updated.isFavorite.toggle()
            PromptActions.favoriteToggled(isFavorite: updated.isFavorite)
            try database.write { db in
                try VibePrompt.update(updated).execute(db)
            }
        }
    }
}

#Preview {
    let _ = prepareDependencies {
        $0.defaultDatabase = try! appDatabase()
    }
    SearchView()
}
