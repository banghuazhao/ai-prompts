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
        case mostUsed = "Most Used"
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

    @ObservationIgnored
    @Shared(.appStorage("promptSortOption")) private var savedSortOption: SortOption = .modifiedDate

    @ObservationIgnored
    @Shared(.appStorage("promptFilterOption")) private var savedFilterOption: FilterOption = .all

    /// "New" is a quick look opened from the banner, so it isn't remembered between launches.
    private var showsNewOnly = false

    var sortOption: SortOption {
        get { savedSortOption }
        set { $savedSortOption.withLock { $0 = newValue } }
    }

    var filterOption: FilterOption {
        get { showsNewOnly ? .new : savedFilterOption }
        set {
            showsNewOnly = newValue == .new
            if newValue != .new {
                $savedFilterOption.withLock { $0 = newValue }
            }
        }
    }

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
    @FetchAll(
        PromptUsage
            .all
            .order { $0.lastUsedDate.desc() }
        , animation: .default) var usages

    @ObservationIgnored
    @Dependency(\.defaultDatabase) var database

    /// A prompt opened from the Recently Used shelf.
    var recentPromptDestination: Prompt?

    @CasePathable
    enum Route {
        case showingAddPrompt
        case editingPrompt(Prompt)
        case showingDeleteAlert(Prompt)
        case addingDraft(Prompt.Draft)
        case selectCategory
        case customizing(Prompt)
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
        case .mostUsed:
            let usageByPromptID = Dictionary(usages.map { ($0.promptID, $0) }, uniquingKeysWith: { first, _ in first })
            prompts = prompts.sorted { lhs, rhs in
                let lhsUsage = usageByPromptID[lhs.id]
                let rhsUsage = usageByPromptID[rhs.id]
                let lhsCount = lhsUsage?.useCount ?? 0
                let rhsCount = rhsUsage?.useCount ?? 0
                if lhsCount != rhsCount {
                    return lhsCount > rhsCount
                }
                let lhsDate = lhsUsage?.lastUsedDate ?? .distantPast
                let rhsDate = rhsUsage?.lastUsedDate ?? .distantPast
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }
                return lhs.modifiedDate > rhs.modifiedDate
            }
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
    
    /// Most recently used first. Usage rows are deleted with their prompt, but stay defensive.
    var recentPrompts: [Prompt] {
        let promptsByID = Dictionary(prompts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return Array(usages.lazy.compactMap { promptsByID[$0.promptID] }.prefix(PromptUsage.recentLimit))
    }

    /// Only on the unfiltered library, where it doesn't compete with what the user is looking for.
    var showsRecentlyUsed: Bool {
        searchText.isEmpty && filterOption == .all && selectedCategory == nil && !usages.isEmpty
    }

    func onCopy(_ prompt: Prompt) {
        PromptActions.copy(prompt.prompt)
        PromptUsage.record(promptID: prompt.id)
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

    func onDuplicate(_ prompt: Prompt) {
        route = .addingDraft(Prompt.Draft(duplicating: prompt))
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

    // MARK: - Selecting several prompts

    /// Selection mode, for favoriting, moving, sharing or deleting many prompts at once.
    var isSelecting = false
    var selectedIDs: Set<Prompt.ID> = []
    var showingDeleteSelectedAlert = false
    var showingMoveSelected = false

    func toggleSelecting() {
        withAnimation {
            isSelecting.toggle()
            selectedIDs = []
        }
    }

    func toggleSelection(_ prompt: Prompt) {
        if selectedIDs.contains(prompt.id) {
            selectedIDs.remove(prompt.id)
        } else {
            selectedIDs.insert(prompt.id)
        }
    }

    var allVisibleSelected: Bool {
        !filteredPrompts.isEmpty && filteredPrompts.allSatisfy { selectedIDs.contains($0.id) }
    }

    func toggleSelectAll() {
        let visible = filteredPrompts.map(\.id)
        if allVisibleSelected {
            selectedIDs.subtract(visible)
        } else {
            selectedIDs.formUnion(visible)
        }
    }

    /// Selected prompts in the order they're listed, followed by any that a search or filter now hides.
    var selectedPrompts: [Prompt] {
        let visible = filteredPrompts.filter { selectedIDs.contains($0.id) }
        let visibleIDs = Set(visible.map(\.id))
        return visible + prompts.filter { selectedIDs.contains($0.id) && !visibleIDs.contains($0.id) }
    }

    /// When every selected prompt is already a favorite, the favorite action removes them instead.
    var selectionIsAllFavorites: Bool {
        let selected = selectedPrompts
        return !selected.isEmpty && selected.allSatisfy(\.isFavorite)
    }

    func favoriteSelected() {
        let isFavorite = !selectionIsAllFavorites
        let changed = selectedPrompts.filter { $0.isFavorite != isFavorite }
        withErrorReporting {
            try database.write { db in
                for prompt in changed {
                    var updatedPrompt = prompt
                    updatedPrompt.isFavorite = isFavorite
                    try Prompt.update(updatedPrompt).execute(db)
                }
            }
        }
        if !changed.isEmpty {
            PromptActions.favoriteToggled(isFavorite: isFavorite)
        }
        finishSelecting()
    }

    /// The selection's category, for the picker's checkmark. `isShared` is false when the selected
    /// prompts are in different categories, so nothing is checked.
    var moveCategoryChoice: (selected: PromptCategory.ID?, isShared: Bool) {
        let categoryIDs = Set(selectedPrompts.map(\.categoryID))
        return (categoryIDs.first ?? nil, categoryIDs.count == 1)
    }

    func onMoveSelected(to category: PromptCategory?) {
        let changed = selectedPrompts.filter { $0.categoryID != category?.id }
        withErrorReporting {
            try database.write { db in
                for prompt in changed {
                    var updatedPrompt = prompt
                    updatedPrompt.categoryID = category?.id
                    try Prompt.update(updatedPrompt).execute(db)
                }
            }
        }
        finishSelecting()
        Task {
            showingMoveSelected = false
        }
    }

    var selectedShareText: String {
        selectedPrompts
            .map { "\($0.act)\n\n\($0.prompt)" }
            .joined(separator: "\n\n---\n\n")
    }

    /// Library prompts stay deleted: ContentSync only ever inserts an item once.
    func confirmDeleteSelected() {
        let doomed = prompts.filter { selectedIDs.contains($0.id) }
        withErrorReporting {
            try database.write { db in
                for prompt in doomed {
                    try Prompt.delete(prompt).execute(db)
                }
            }
        }
        finishSelecting()
    }

    private func finishSelecting() {
        withAnimation {
            selectedIDs = []
            isSelecting = false
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
        route = .addingDraft(draft)
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

                    if model.showsRecentlyUsed {
                        let recentPrompts = model.recentPrompts
                        if !recentPrompts.isEmpty {
                            RecentlyUsedShelf(
                                prompts: recentPrompts,
                                onSelect: { model.recentPromptDestination = $0 },
                                onCustomize: { model.route = .customizing($0) },
                                onRemove: { PromptUsage.remove(promptID: $0.id) },
                                onClear: { PromptUsage.removeAll() }
                            )
                            .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 18, trailing: 18))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
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
                        Group {
                            if model.isSelecting {
                                let isSelected = model.selectedIDs.contains(prompt.id)
                                Button {
                                    Haptics.shared.vibrateIfEnabled()
                                    model.toggleSelection(prompt)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .font(.title3)
                                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                                        PromptRowView(
                                            prompt: prompt,
                                            onFavorite: {}
                                        )
                                        .allowsHitTesting(false)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(isSelected ? .isSelected : [])
                            } else {
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
                                            model.onCopy(prompt)
                                        }) {
                                            Label("Copy", systemImage: "doc.on.doc")
                                        }
                                        OpenInDefaultLLMButton(
                                            prompt: prompt.prompt,
                                            onNeedsBlanks: { model.route = .customizing(prompt) }
                                        ) {
                                            PromptUsage.record(promptID: prompt.id)
                                        }
                                        Button(action: {
                                            Haptics.shared.vibrateIfEnabled()
                                            model.onEdit(prompt)
                                        }) {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        Button(action: {
                                            Haptics.shared.vibrateIfEnabled()
                                            model.onDuplicate(prompt)
                                        }) {
                                            Label("Duplicate", systemImage: "plus.square.on.square")
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
                        }
                        .listRowInsets(EdgeInsets(top: 3, leading: 18, bottom: 11, trailing: 18))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .promptSwipeActions(
                            isFavorite: prompt.isFavorite,
                            onFavorite: { model.onFavorite(prompt) },
                            onCopy: { model.onCopy(prompt) },
                            onDelete: { model.onDeleteRequest(prompt) }
                        )
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
                .navigationDestination(item: $model.recentPromptDestination) { prompt in
                    PromptDetailView(model: PromptDetailModel(prompt: prompt))
                }
            }
            .safeAreaInset(edge: .bottom) {
                if model.isSelecting {
                    HStack(spacing: 24) {
                        Button(model.allVisibleSelected ? "Deselect All" : "Select All") {
                            Haptics.shared.vibrateIfEnabled()
                            model.toggleSelectAll()
                        }
                        Spacer(minLength: 0)
                        Group {
                            Button {
                                Haptics.shared.vibrateIfEnabled()
                                model.favoriteSelected()
                            } label: {
                                Label(
                                    model.selectionIsAllFavorites ? "Remove from Favorites" : "Add to Favorites",
                                    systemImage: model.selectionIsAllFavorites ? "heart.slash" : "heart"
                                )
                            }
                            Button {
                                Haptics.shared.vibrateIfEnabled()
                                model.showingMoveSelected = true
                            } label: {
                                Label("Move to Category", systemImage: "folder")
                            }
                            ShareLink(item: model.selectedShareText) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .simultaneousGesture(TapGesture().onEnded { PromptActions.share() })
                            Button(role: .destructive) {
                                Haptics.shared.vibrateIfEnabled()
                                model.showingDeleteSelectedAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                        .labelStyle(.iconOnly)
                        .imageScale(.large)
                        .disabled(model.selectedIDs.isEmpty)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.bar)
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .searchable(text: $model.searchText, prompt: "Search prompts")
            .navigationTitle(model.isSelecting ? Text("\(model.selectedIDs.count) Selected") : Text("Prompts"))
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
                
                if model.isSelecting {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            Haptics.shared.vibrateIfEnabled()
                            model.toggleSelecting()
                        }
                    }
                } else {
                    // Less frequent actions share one menu, so the title isn't squeezed.
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button("Select Prompts", systemImage: "checkmark.circle") {
                                Haptics.shared.vibrateIfEnabled()
                                model.toggleSelecting()
                            }
                            Button("Generate Prompt Idea", systemImage: "sparkles") {
                                Haptics.shared.vibrateIfEnabled()
                                model.generateMarkovPrompt()
                            }
                        } label: {
                            Label("More", systemImage: "ellipsis")
                        }
                        .help("More actions")
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
            .sheet(item: $model.route.customizing, id: \.self) { prompt in
                PromptCustomizeView(title: prompt.act, prompt: prompt.prompt) {
                    PromptUsage.record(promptID: prompt.id)
                }
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
            .alert(
                "Delete \(model.selectedIDs.count) Prompts?",
                isPresented: $model.showingDeleteSelectedAlert
            ) {
                Button("Delete", role: .destructive) {
                    Haptics.shared.vibrateIfEnabled()
                    model.confirmDeleteSelected()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone.")
            }
            .sheet(isPresented: $model.showingMoveSelected) {
                let choice = model.moveCategoryChoice
                CategoryFormView(
                    model: CategoryFormModel(
                        selectedCategory: choice.selected,
                        marksSelection: choice.isShared,
                        onSelect: { category in
                            model.onMoveSelected(to: category)
                        }
                    )
                )
                .presentationDetents([.fraction(0.7), .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $model.route.addingDraft, id: \.self) { draft in
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
