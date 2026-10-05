import SharingGRDB
import SwiftUI

/// Searches prompts and vibe prompts together. Shown as the search tab on iOS 26.
struct SearchView: View {
    @FetchAll(Prompt.all, animation: .default) private var prompts
    @FetchAll(VibePrompt.all, animation: .default) private var vibePrompts
    @Dependency(\.defaultDatabase) private var database

    @State private var query = ""
    @State private var aiSearch = AISearchState()

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

    /// Natural language search is offered once a query is typed, on devices that can run it.
    private var canAskAI: Bool {
        !trimmedQuery.isEmpty && OnDeviceAI.status == .available
    }

    var body: some View {
        NavigationStack {
            let promptResults = matchingPrompts
            let vibePromptResults = matchingVibePrompts
            List {
                if canAskAI {
                    aiSection
                }
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
                } else if promptResults.isEmpty && vibePromptResults.isEmpty && !canAskAI {
                    ContentUnavailableView.search(text: trimmedQuery)
                }
            }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Prompts and vibe prompts")
            .onSubmit(of: .search) {
                if canAskAI {
                    findWithAI()
                }
            }
        }
    }

    // MARK: - Apple Intelligence

    @ViewBuilder
    private var aiSection: some View {
        let hasResults = aiSearch.query == trimmedQuery
        Section {
            if aiSearch.isSearching {
                Label {
                    Text("Finding prompts…")
                        .foregroundStyle(.secondary)
                } icon: {
                    ProgressView()
                }
            } else if hasResults, let failure = aiSearch.failure {
                Label(failure.message, systemImage: "exclamationmark.bubble")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if hasResults {
                if aiSearch.prompts.isEmpty && aiSearch.vibePrompts.isEmpty {
                    Text("No prompts fit this request. Try describing it differently.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                ForEach(aiSearch.prompts) { prompt in
                    NavigationLink(destination: PromptDetailView(model: PromptDetailModel(prompt: prompt))) {
                        PromptRowView(prompt: prompt) {
                            toggleFavorite(prompt)
                        }
                    }
                }
                ForEach(aiSearch.vibePrompts) { vibePrompt in
                    NavigationLink(destination: VibePromptDetailView(model: VibePromptDetailModel(vibePrompt: vibePrompt))) {
                        VibePromptRowView(vibePrompt: vibePrompt) {
                            toggleFavorite(vibePrompt)
                        }
                    }
                }
            } else {
                Button {
                    Haptics.shared.vibrateIfEnabled()
                    findWithAI()
                } label: {
                    Label("Find the best prompts with Apple Intelligence", systemImage: "sparkles")
                }
            }
        } header: {
            if hasResults || aiSearch.isSearching {
                Text("Suggested by Apple Intelligence")
            }
        }
    }

    private func findWithAI() {
        guard #available(iOS 26.0, *) else { return }
        let request = trimmedQuery
        // Favorites and recently changed prompts go first in case the list has to be trimmed.
        let orderedPrompts = prompts.sorted {
            ($0.isFavorite ? 1 : 0, $0.modifiedDate) > ($1.isFavorite ? 1 : 0, $1.modifiedDate)
        }
        let promptsByTitle = Dictionary(orderedPrompts.map { ($0.act, $0) }, uniquingKeysWith: { first, _ in first })
        let vibePromptsByTitle = Dictionary(vibePrompts.map { ($0.app, $0) }, uniquingKeysWith: { first, _ in first })
        let titles = Array((orderedPrompts.map(\.act) + vibePrompts.map(\.app)).prefix(AISearchState.maxTitles))

        aiSearch = AISearchState(query: request, isSearching: true)
        Task {
            var result = AISearchState(query: request)
            do {
                let matches = try await PromptAssistant.findPrompts(matching: request, among: titles)
                result.prompts = matches.compactMap { promptsByTitle[$0] }
                result.vibePrompts = matches.compactMap { promptsByTitle[$0] == nil ? vibePromptsByTitle[$0] : nil }
            } catch {
                result.failure = OnDeviceAIFailure(error)
            }
            // Ignore answers for a query the user has already changed.
            if aiSearch.query == request {
                aiSearch = result
            }
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

/// The latest natural language search and its results.
private struct AISearchState {
    /// Keeps the list of titles (and the request) inside the on-device model's context window.
    static let maxTitles = 300

    var query: String?
    var isSearching = false
    var prompts: [Prompt] = []
    var vibePrompts: [VibePrompt] = []
    var failure: OnDeviceAIFailure?
}
