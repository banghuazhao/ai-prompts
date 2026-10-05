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
                if trimmedQuery.isEmpty {
                    searchDiscovery
                }
                if canAskAI {
                    aiSection
                }
                if !trimmedQuery.isEmpty && promptResults.isEmpty && vibePromptResults.isEmpty {
                    noResultsCard
                }
                if !promptResults.isEmpty {
                    Section("Prompts") {
                        ForEach(promptResults) { prompt in
                            NavigationLink(destination: PromptDetailView(model: PromptDetailModel(prompt: prompt))) {
                                PromptRowView(prompt: prompt) {
                                    toggleFavorite(prompt)
                                }
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
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
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AIStudioPalette.canvas)
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Prompts and vibe prompts")
            .onSubmit(of: .search) {
                if canAskAI {
                    findWithAI()
                }
            }
        }
    }

    private var searchDiscovery: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text("DISCOVER WITH AI")
                    .font(.caption.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(AIStudioPalette.cyan)
                Text("The right prompt starts here")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Search by title, topic, or the task you want to tackle.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.94))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("TRY A SEARCH")
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.9))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        suggestedSearch("Write better emails", query: "Write better emails", systemImage: "envelope")
                        suggestedSearch("Explain code", query: "Explain code", systemImage: "chevron.left.forwardslash.chevron.right")
                        suggestedSearch("Plan a trip", query: "Plan a trip", systemImage: "map")
                    }
                }
                .scrollClipDisabled()
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AIStudioPalette.heroGradient, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .listRowInsets(EdgeInsets(top: 18, leading: 16, bottom: 8, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func suggestedSearch(_ title: LocalizedStringKey, query searchQuery: String, systemImage: String) -> some View {
        Button {
            Haptics.shared.vibrateIfEnabled()
            query = searchQuery
        } label: {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(.white.opacity(0.15), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var noResultsCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.headline)
                .foregroundStyle(AIStudioPalette.violet)
                .frame(width: 44, height: 44)
                .background(AIStudioPalette.violet.opacity(0.11), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text("No exact matches")
                    .font(.headline)
                if canAskAI {
                    Text("Try Apple Intelligence, or search with broader words.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Try searching with broader words or a different topic.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AIStudioPalette.surface, in: RoundedRectangle(cornerRadius: 20))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
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
                    HStack(spacing: 14) {
                        Image(systemName: "sparkles")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AIStudioPalette.violet)
                            .frame(width: 44, height: 44)
                            .background(AIStudioPalette.violet.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Find with Apple Intelligence")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("Get suggestions from your prompt library")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AIStudioPalette.violet)
                    }
                    .padding(14)
                    .background(AIStudioPalette.surface, in: RoundedRectangle(cornerRadius: 20))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Find the best prompts with Apple Intelligence")
            }
        } header: {
            if hasResults || aiSearch.isSearching {
                Text("Suggested by Apple Intelligence")
            }
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
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
