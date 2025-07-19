import Dependencies
import SharingGRDB
import SwiftUI
import SwiftUINavigation

@Observable
@MainActor
class PromptListModel {
    var searchText = ""
    enum SortOption: String, CaseIterable, Identifiable {
        case modifiedDate = "Modified Date"
        case title = "Title"
        case characterLengthAsc = "Character Length ↑"
        case characterLengthDesc = "Character Length ↓"
        var id: String { rawValue }
    }

    enum FilterOption: String, CaseIterable, Identifiable {
        case all = "All"
        case forDevelopers = "For Developers"
        var id: String { rawValue }
    }

    var sortOption: SortOption = .modifiedDate
    var filterOption: FilterOption = .all
    var isDefault: Bool {
        sortOption == .modifiedDate && filterOption == .all
    }

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
        case showingMarkovAddPrompt(Prompt.Draft)
    }

    var route: Route?

    var filteredPrompts: [Prompt] {
        var prompts = prompts
        // Filter
        if filterOption == .forDevelopers {
            prompts = prompts.filter { $0.forDevs }
        }
        // Search
        if !searchText.isEmpty {
            prompts = searchPrompts(query: searchText)
        }
        // Sort
        switch sortOption {
        case .modifiedDate:
            prompts = prompts.sorted { $0.modifiedDate > $1.modifiedDate }
        case .title:
            prompts = prompts.sorted { $0.act.localizedCaseInsensitiveCompare($1.act) == .orderedAscending }
        case .characterLengthAsc:
            prompts = prompts.sorted { $0.prompt.count < $1.prompt.count }
        case .characterLengthDesc:
            prompts = prompts.sorted { $0.prompt.count > $1.prompt.count }
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

    // MARK: - Markov Generator State

    @ObservationIgnored
    var markovGenerator: MarkovTextGenerator? = nil
    var corpusLoaded = false

    func loadCorpusIfNeeded() {
        guard !corpusLoaded else { return }
        if let url = Bundle.main.url(forResource: "prompts", withExtension: "csv"),
           let content = try? String(contentsOf: url) {
            let lines = content.components(separatedBy: "\n").dropFirst() // skip header
            let prompts = lines.compactMap { line -> String? in
                let parts = line.components(separatedBy: ",")
                if parts.count > 1 {
                    return parts[1].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
                }
                return nil
            }.filter { !$0.isEmpty }
            markovGenerator = MarkovTextGenerator(corpus: prompts)
            corpusLoaded = true
        }
    }

    func generateMarkovPrompt() {
        loadCorpusIfNeeded()
        if let generator = markovGenerator {
            if let url = Bundle.main.url(forResource: "prompts", withExtension: "csv"),
               let content = try? String(contentsOf: url) {
                let act = "AI Generated Act"
                let generated = generator.generatePrompt()
                let draft = Prompt.Draft(act: act, prompt: generated)
                route = .showingMarkovAddPrompt(draft)
            } else {
                let draft = Prompt.Draft(act: "AI Generated Act", prompt: "Failed to load corpus.")
                route = .showingMarkovAddPrompt(draft)
            }
        } else {
            let draft = Prompt.Draft(act: "AI Generated Act", prompt: "Failed to load corpus.")
            route = .showingMarkovAddPrompt(draft)
        }
    }
}

struct PromptListView: View {
    @State private var model = PromptListModel()

    var body: some View {
        NavigationStack {
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
                            Button(action: {
                                Haptics.shared.vibrateIfEnabled()
                                model.onEdit(prompt)
                            }) {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(action: {
                                Haptics.shared.vibrateIfEnabled()
                                model.onFavorite(prompt)
                            }) {
                                Label(prompt.isFavorite ? "Unfavorite" : "Favorite", systemImage: prompt.isFavorite ? "heart.slash" : "heart")
                            }
                            Button(role: .destructive, action: {
                                Haptics.shared.vibrateIfEnabled()
                                model.onDeleteRequest(prompt)
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .scrollDismissesKeyboard(.immediately)
            .searchable(text: $model.searchText)
            .navigationTitle("Prompts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Section(header: Text("Sort By")) {
                            Picker("Sort", selection: $model.sortOption) {
                                ForEach(PromptListModel.SortOption.allCases) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        }
                        Section(header: Text("Filter")) {
                            Picker("Filter", selection: $model.filterOption) {
                                ForEach(PromptListModel.FilterOption.allCases) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        }
                    } label: {
                        Label("Sort & Filter", systemImage: model.isDefault ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Haptics.shared.vibrateIfEnabled()
                        model.generateMarkovPrompt()
                    }) {
                        Image(systemName: "sparkles")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Haptics.shared.vibrateIfEnabled()
                        model.route = .showingAddPrompt
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: Binding($model.route.showingAddPrompt)) {
                PromptFormView(
                    model: PromptFormModel { _ in
                        model.route = nil
                    }
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
                        Haptics.shared.vibrateIfEnabled()
                        model.confirmDelete(prompt)
                    }
                    Button("Cancel", role: .cancel) {
                        Haptics.shared.vibrateIfEnabled()
                    }
                },
                message: { prompt in
                    Text("Are you sure you want to delete \(prompt.act)? This action cannot be undone.")
                }
            )
            .sheet(item: $model.route.showingMarkovAddPrompt, id: \.self) { draft in
                PromptFormView(
                    model: PromptFormModel(
                        prompt: draft
                    ) { _ in
                        model.route = nil
                    }
                )
            }
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
                    Haptics.shared.vibrateIfEnabled()
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
