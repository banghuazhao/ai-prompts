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
        case new = "New"
        case forDevelopers = "For Developers"
        var id: String { rawValue }
    }
    
    @ObservationIgnored
    @Shared(.appStorage("selectedCategory")) var selectedCategory: PromptCategory.ID?

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
        case selectCategory
    }

    var route: Route?

    var filteredPrompts: [Prompt] {
        var prompts = prompts
        if let selectedCategory {
            prompts = prompts.filter { $0.categoryID == selectedCategory }
        }
        
        // Filter
        switch filterOption {
        case .all:
            break
        case .new:
            prompts = prompts.filter(\.isNew)
        case .forDevelopers:
            prompts = prompts.filter { $0.forDevs }
        }
        // Search
        if !searchText.isEmpty {
            prompts = searchPrompts(prompts, query: searchText)
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

    func searchPrompts(_ prompts: [Prompt], query: String) -> [Prompt] {
        guard !query.isEmpty else { return prompts }

        let lowercasedQuery = query.lowercased()
        return prompts.filter { prompt in
            prompt.act.lowercased().contains(lowercasedQuery) ||
                prompt.prompt.lowercased().contains(lowercasedQuery)
        }
    }
    
    var newPromptsCount: Int {
        prompts.filter(\.isNew).count
    }

    var showsNewPromptsBanner: Bool {
        newPromptsCount > 0 && filterOption != .new && searchText.isEmpty
    }

    func onTapNewPromptsBanner() {
        withAnimation {
            filterOption = .new
            $selectedCategory.withLock { $0 = nil }
        }
    }

    func onTapSelectCategory() {
        route = .selectCategory
    }
    
    func onSelectCategory(_ category: PromptCategory?) {
        withAnimation {
            $selectedCategory.withLock {
                $0 = category?.id
            }
        }
        Task {
            route = nil
        }
    }

    func onFavorite(_ prompt: Prompt) {
        withErrorReporting {
            var updatedPrompt = prompt
            updatedPrompt.isFavorite.toggle()
            PromptActions.favoriteToggled(isFavorite: updatedPrompt.isFavorite)
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
        let corpus = DataManager.shared.loadPromptsDraft().map(\.prompt)
        markovGenerator = MarkovTextGenerator(corpus: corpus)
        corpusLoaded = true
    }

    func generateMarkovPrompt() {
        loadCorpusIfNeeded()
        let generated = markovGenerator?.generatePrompt() ?? ""
        let draft = Prompt.Draft(
            act: "AI Generated Act",
            prompt: generated.isEmpty ? "Failed to load corpus." : generated
        )
        route = .showingMarkovAddPrompt(draft)
    }
}

struct PromptListView: View {
    @State private var model = PromptListModel()

    var body: some View {
        NavigationStack {
            VStack {
                List {
                    AIStudioLibraryHero(
                        eyebrow: "THE PROMPT LIBRARY",
                        title: "Find your next idea.",
                        subtitle: "Thoughtful prompts for writing, learning, creating and everything in between.",
                        promptCount: model.prompts.count,
                        symbol: "sparkles.rectangle.stack",
                        actionTitle: "Categories"
                    ) {
                        Haptics.shared.vibrateIfEnabled()
                        model.onTapSelectCategory()
                    }
                    .listRowInsets(EdgeInsets(top: 16, leading: 18, bottom: 18, trailing: 18))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    if model.showsNewPromptsBanner {
                        NewPromptsBanner(count: model.newPromptsCount) {
                            model.onTapNewPromptsBanner()
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 18, trailing: 18))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }

                    HStack {
                        Text(model.searchText.isEmpty ? "Explore prompts" : "Search results")
                            .font(.title3.bold())
                        Spacer()
                        Text("\(model.filteredPrompts.count)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 22, bottom: 8, trailing: 22))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    ForEach(model.filteredPrompts) { prompt in
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
                        .listRowInsets(EdgeInsets(top: 3, leading: 18, bottom: 11, trailing: 18))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }

                    if model.filteredPrompts.isEmpty {
                        ContentUnavailableView(
                            model.searchText.isEmpty ? "No prompts here yet" : "No matching prompts",
                            systemImage: "sparkle.magnifyingglass",
                            description: Text(model.searchText.isEmpty ? "Try another category or filter." : "Try a different search term.")
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(AIStudioPalette.canvas)
            }
            .scrollDismissesKeyboard(.immediately)
            .searchable(text: $model.searchText, prompt: "Search prompts")
            .navigationTitle("Prompts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Section(header: Text("Sort By")) {
                            Picker("Sort", selection: $model.sortOption) {
                                ForEach(PromptListModel.SortOption.allCases) { option in
                                    Text(LocalizedStringKey(option.rawValue)).tag(option)
                                }
                            }
                        }
                        Section(header: Text("Filter")) {
                            Picker("Filter", selection: $model.filterOption) {
                                ForEach(PromptListModel.FilterOption.allCases) { option in
                                    Text(LocalizedStringKey(option.rawValue)).tag(option)
                                }
                            }
                        }
                    } label: {
                        Label("Sort & Filter", systemImage: model.isDefault ? "arrow.up.arrow.down" : "arrow.up.arrow.down.circle.fill")
                    }
                    .help("Sort and filter prompts")
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        Haptics.shared.vibrateIfEnabled()
                        model.onTapSelectCategory()
                    }) {
                        if model.selectedCategory != nil {
                            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        } else {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }
                    }
                    .accessibilityLabel("Choose category")
                    .help("Choose category")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Haptics.shared.vibrateIfEnabled()
                        model.generateMarkovPrompt()
                    }) {
                        Image(systemName: "sparkles")
                    }
                    .accessibilityLabel("Generate prompt idea")
                    .help("Generate prompt idea")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Haptics.shared.vibrateIfEnabled()
                        model.route = .showingAddPrompt
                    }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add prompt")
                    .help("Add prompt")
                }
            }
            .sheet(isPresented: Binding($model.route.showingAddPrompt)) {
                PromptFormView(
                    model: PromptFormModel { _ in
                        model.route = nil
                    }
                )
            }
            .sheet(isPresented: Binding($model.route.selectCategory)) {
                CategorySelectionSheet(
                    selectedCategory: model.selectedCategory,
                    onSelect: { category in
                        model.onSelectCategory(category)
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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
