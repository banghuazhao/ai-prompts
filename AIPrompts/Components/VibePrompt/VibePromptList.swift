import Dependencies
import SharingGRDB
import SwiftUI
import SwiftUIFlowLayout
import SwiftUINavigation
import UIKit

@Observable
@MainActor
class VibePromptListModel {
    var searchText = ""
    var showingAddPrompt = false
    enum SortOption: String, CaseIterable, Identifiable {
        case modifiedDate = "Modified Date"
        case mostUsed = "Most Used"
        case title = "Title"
        case characterLengthAsc = "Character Length ↑"
        case characterLengthDesc = "Character Length ↓"
        var id: String { rawValue }
    }

    @ObservationIgnored
    @Shared(.appStorage("vibePromptSortOption")) private var savedSortOption: SortOption = .modifiedDate

    var sortOption: SortOption {
        get { savedSortOption }
        set { $savedSortOption.withLock { $0 = newValue } }
    }

    var isDefault: Bool {
        sortOption == .modifiedDate
    }

    @ObservationIgnored
    @FetchAll(
        VibePrompt
            .all
            .order { $0.modifiedDate.desc() }
        , animation: .default) var vibePrompts

    @ObservationIgnored
    @FetchAll(VibePromptUsage.all, animation: .default) var usages

    @ObservationIgnored
    @Dependency(\.defaultDatabase) var database

    var markovGenerator: MarkovTextGenerator?
    var corpusLoaded = false

    func loadCorpusIfNeeded() {
        guard !corpusLoaded else { return }
        let corpus = DataManager.shared.loadVibePromptsDraft().map(\.prompt)
        markovGenerator = MarkovTextGenerator(corpus: corpus)
        corpusLoaded = true
    }

    func generateMarkovPrompt() {
        loadCorpusIfNeeded()
        let generated = markovGenerator?.generatePrompt() ?? ""
        let draft = VibePrompt.Draft(
            app: String(localized: "New App Idea"),
            prompt: generated.isEmpty ? "Failed to load corpus." : generated
        )
        route = .addingDraft(draft)
    }

    @CasePathable
    enum Route {
        case showingAddVibePrompt
        case editingPrompt(VibePrompt)
        case isFilterTechShareSheetPresented
        case addingDraft(VibePrompt.Draft)
        case generatingIdea
        case customizing(VibePrompt)
    }

    var route: Route?

    // MARK: - Recent searches

    /// Shared with the other search fields, newest first.
    var recentSearches = RecentSearches.load()

    /// Called when a search is submitted or one of its results is opened.
    func rememberSearch() {
        let updated = RecentSearches.adding(searchText, to: RecentSearches.load())
        guard updated != recentSearches else { return }
        recentSearches = updated
        RecentSearches.save(updated)
    }

    func reloadRecentSearches() {
        recentSearches = RecentSearches.load()
    }

    // MARK: - New prompts from Apple Intelligence or the clipboard

    /// Written by Apple Intelligence, waiting for the idea sheet to close before the form opens.
    @ObservationIgnored
    private var generatedDraft: VibePrompt.Draft?

    /// Apple Intelligence writes a prompt for an app of the user's choosing. Devices without it
    /// get a remix of the library instead.
    func onGenerateIdea() {
        if OnDeviceAI.status == .available {
            route = .generatingIdea
        } else {
            generateMarkovPrompt()
        }
    }

    func generateIdea(about topic: String) async throws {
        guard #available(iOS 26.0, *) else { return }
        let idea = try await PromptAssistant.generateVibeIdea(about: topic)
        generatedDraft = VibePrompt.Draft(
            app: idea.appName,
            prompt: idea.prompt,
            techstack: idea.techStack.joined(separator: ", ")
        )
    }

    /// Two sheets can't be swapped in one step, so the form opens once the idea sheet is gone.
    func onIdeaSheetDismissed() {
        guard let draft = generatedDraft else { return }
        generatedDraft = nil
        route = .addingDraft(draft)
    }

    var canAddFromClipboard: Bool {
        UIPasteboard.general.hasStrings
    }

    /// Opens the add form with the copied text. A short first line becomes the app name.
    func onAddFromClipboard() {
        guard let text = UIPasteboard.general.string,
              let imported = ImportedPrompt(text: text)
        else { return }
        route = .addingDraft(VibePrompt.Draft(app: imported.title, prompt: imported.prompt))
    }

    var allTechStacks: [String] {
        Array(Set(vibePrompts.flatMap { $0.techstackArray }))
            .sorted()
    }

    private static let selectedTechStacksKey = "vibePromptSelectedTechStacks"

    private var savedTechStacks = UserDefaults.standard.stringArray(forKey: VibePromptListModel.selectedTechStacksKey) ?? []

    /// Remembered between launches. A stack that no prompt uses anymore stays visible as a chip,
    /// so it's easy to remove.
    var selectedTechStacks: [String] {
        get { savedTechStacks }
        set {
            savedTechStacks = newValue
            UserDefaults.standard.set(newValue, forKey: Self.selectedTechStacksKey)
        }
    }

    var filteredVibePrompts: [VibePrompt] {
        var new = vibePrompts
        if !selectedTechStacks.isEmpty {
            new = new.filter { prompt in
                let techs = Set(prompt.techstackArray.map { $0.lowercased() })
                return selectedTechStacks.allSatisfy { token in
                    techs.contains(token.lowercased())
                }
            }
        }
        // Sort
        switch sortOption {
        case .modifiedDate:
            new = new.sorted { $0.modifiedDate > $1.modifiedDate }
        case .mostUsed:
            let usageByVibePromptID = Dictionary(usages.map { ($0.vibePromptID, $0) }, uniquingKeysWith: { first, _ in first })
            new = new.sorted { lhs, rhs in
                let lhsUsage = usageByVibePromptID[lhs.id]
                let rhsUsage = usageByVibePromptID[rhs.id]
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
            new = new.sorted { $0.app.localizedCaseInsensitiveCompare($1.app) == .orderedAscending }
        case .characterLengthAsc:
            new = Self.sortedByLength(new, ascending: true)
        case .characterLengthDesc:
            new = Self.sortedByLength(new, ascending: false)
        }
        // Search: best matches first, with the chosen sort breaking ties.
        let search = TextSearch(searchText)
        if !search.isEmpty {
            new = search.rank(new, title: { $0.app }, fields: { [$0.prompt, $0.techstack, $0.contributor] })
        }
        return new
    }

    /// Counting characters walks the whole string, so do it once per prompt rather than per comparison.
    private static func sortedByLength(_ vibePrompts: [VibePrompt], ascending: Bool) -> [VibePrompt] {
        vibePrompts
            .map { (vibePrompt: $0, length: $0.prompt.count) }
            .sorted { ascending ? $0.length < $1.length : $0.length > $1.length }
            .map { $0.vibePrompt }
    }

    func onFavorite(_ prompt: VibePrompt) {
        withErrorReporting {
            var updatedPrompt = prompt
            updatedPrompt.isFavorite.toggle()
            PromptActions.favoriteToggled(isFavorite: updatedPrompt.isFavorite)
            try database.write { db in
                try VibePrompt
                    .update(updatedPrompt)
                    .execute(db)
            }
        }
    }

    func onCopy(_ prompt: VibePrompt) {
        PromptActions.copy(prompt.prompt)
        VibePromptUsage.record(vibePromptID: prompt.id)
    }

    func onEdit(_ prompt: VibePrompt) {
        route = .editingPrompt(prompt)
    }

    func onDuplicate(_ prompt: VibePrompt) {
        route = .addingDraft(VibePrompt.Draft(duplicating: prompt))
    }

    /// Deletes right away; the banner that follows offers Undo.
    func onDelete(_ prompt: VibePrompt) {
        PromptTrash.delete(prompt)
    }

    func onTapFilterTechStackSheet() {
        route = .isFilterTechShareSheetPresented
    }

    func onDeselectTechStack(_ techStack: String) {
        withAnimation {
            if let idx = selectedTechStacks.firstIndex(of: techStack) {
                selectedTechStacks.remove(at: idx)
            }
        }
    }

    func onSelectTechStack(_ techStack: String) {
        withAnimation {
            if let idx = selectedTechStacks.firstIndex(of: techStack) {
                selectedTechStacks.remove(at: idx)
            } else {
                selectedTechStacks.append(techStack)
            }
        }
    }
}

struct VibePromptListView: View {
    @State private var model = VibePromptListModel()

    var body: some View {
        NavigationStack {
            VStack {
                List {
                    // Filtering and sorting run once per update rather than for every use below.
                    let visibleVibePrompts = model.filteredVibePrompts

                    AIStudioLibraryHero(
                        eyebrow: "VIBE CODING",
                        title: "Build the next big thing.",
                        subtitle: "Ready-to-use ideas for apps, games and tools. Pick a stack and start creating.",
                        promptCount: model.vibePrompts.count,
                        symbol: "laptopcomputer.and.iphone",
                        actionTitle: "Tech stacks"
                    ) {
                        Haptics.shared.vibrateIfEnabled()
                        model.onTapFilterTechStackSheet()
                    }
                    .listRowInsets(EdgeInsets(top: 16, leading: 18, bottom: 18, trailing: 18))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    if !model.selectedTechStacks.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            GlassGroup(spacing: 8) {
                                HStack(spacing: 8) {
                                    ForEach(model.selectedTechStacks, id: \.self) { techStack in
                                        Button(action: {
                                            Haptics.shared.vibrateIfEnabled()
                                            model.onDeselectTechStack(techStack)
                                        }) {
                                            HStack(spacing: 4) {
                                                Text(techStack)
                                                    .font(.callout)
                                                    .foregroundStyle(AIStudioPalette.violet)
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(AIStudioPalette.violet)
                                            }
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 10)
                                            .glassCapsule(tint: AIStudioPalette.violet.opacity(0.15), interactive: true, fallback: AIStudioPalette.violet.opacity(0.15))
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Remove \(techStack) filter")
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .scrollClipDisabled()
                        .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 12, trailing: 18))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }

                    HStack {
                        Text(model.searchText.isEmpty ? "Explore builds" : "Search results")
                            .font(.title3.bold())
                        Spacer()
                        Text("\(visibleVibePrompts.count)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 22, bottom: 8, trailing: 22))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    ForEach(visibleVibePrompts) { vibePrompt in
                        NavigationLink(destination: VibePromptDetailView(model: VibePromptDetailModel(vibePrompt: vibePrompt)).onAppear { model.rememberSearch() }) {
                            VibePromptRowView(vibePrompt: vibePrompt) {
                                model.onFavorite(vibePrompt)
                            }
                            .contextMenu {
                                Button(action: {
                                    Haptics.shared.vibrateIfEnabled()
                                    model.onCopy(vibePrompt)
                                }) {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                OpenInDefaultLLMButton(
                                    prompt: vibePrompt.prompt,
                                    onNeedsBlanks: { model.route = .customizing(vibePrompt) }
                                ) {
                                    VibePromptUsage.record(vibePromptID: vibePrompt.id)
                                }
                                Button(action: {
                                    Haptics.shared.vibrateIfEnabled()
                                    model.onEdit(vibePrompt)
                                }) {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button(action: {
                                    Haptics.shared.vibrateIfEnabled()
                                    model.onDuplicate(vibePrompt)
                                }) {
                                    Label("Duplicate", systemImage: "plus.square.on.square")
                                }
                                Button(action: {
                                    Haptics.shared.vibrateIfEnabled()
                                    model.onFavorite(vibePrompt)
                                }) {
                                    Label(vibePrompt.isFavorite ? "Unfavorite" : "Favorite", systemImage: vibePrompt.isFavorite ? "heart.slash" : "heart")
                                }
                                Button(role: .destructive, action: {
                                    Haptics.shared.vibrateIfEnabled()
                                    model.onDelete(vibePrompt)
                                }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 3, leading: 18, bottom: 11, trailing: 18))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .promptSwipeActions(
                            isFavorite: vibePrompt.isFavorite,
                            onFavorite: { model.onFavorite(vibePrompt) },
                            onCopy: { model.onCopy(vibePrompt) },
                            onDelete: { model.onDelete(vibePrompt) }
                        )
                    }

                    if visibleVibePrompts.isEmpty {
                        ContentUnavailableView(
                            model.searchText.isEmpty ? "No builds here yet" : "No matching builds",
                            systemImage: "sparkle.magnifyingglass",
                            description: Text(model.searchText.isEmpty ? "Try another tech stack filter." : "Try a different search term.")
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .scrollDismissesKeyboard(.immediately)
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(AIStudioPalette.canvas)
                .searchable(text: $model.searchText, prompt: "Search prompts")
                .searchSuggestions {
                    // Recent searches while the field is empty; typing filters the list instead.
                    if model.searchText.isEmpty {
                        ForEach(model.recentSearches, id: \.self) { search in
                            Label(search, systemImage: "clock.arrow.circlepath")
                                .searchCompletion(search)
                        }
                    }
                }
                .onSubmit(of: .search) {
                    model.rememberSearch()
                }
                .onAppear {
                    model.reloadRecentSearches()
                }
                .navigationTitle("Vibe Prompts")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Menu {
                            Picker("Sort", selection: $model.sortOption) {
                                ForEach(VibePromptListModel.SortOption.allCases) { option in
                                    Text(LocalizedStringKey(option.rawValue)).tag(option)
                                }
                            }
                        } label: {
                            Label("Sort", systemImage: model.isDefault ? "arrow.up.arrow.down" : "arrow.up.arrow.down.circle.fill")
                        }
                        .help("Sort vibe prompts")
                    }

                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            Haptics.shared.vibrateIfEnabled()
                            model.onTapFilterTechStackSheet()
                        }) {
                            if model.selectedTechStacks.count == 0 {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                            } else {
                                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            }
                        }
                        .accessibilityLabel("Filter by tech stack")
                        .help("Filter by tech stack")
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            Haptics.shared.vibrateIfEnabled()
                            model.onGenerateIdea()
                        }) {
                            Image(systemName: "sparkles")
                        }
                        .accessibilityLabel("Generate prompt idea")
                        .help("Generate prompt idea")
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        // Tap to add; touch and hold to add from the clipboard.
                        Menu {
                            Button("Add from Clipboard", systemImage: "doc.on.clipboard") {
                                Haptics.shared.vibrateIfEnabled()
                                model.onAddFromClipboard()
                            }
                            .disabled(!model.canAddFromClipboard)
                        } label: {
                            Image(systemName: "plus")
                        } primaryAction: {
                            Haptics.shared.vibrateIfEnabled()
                            model.route = .showingAddVibePrompt
                        }
                        .accessibilityLabel("Add vibe prompt")
                        .help("Add vibe prompt")
                    }
                }
                .sheet(isPresented: Binding($model.route.isFilterTechShareSheetPresented)) {
                    NavigationStack {
                        ScrollView {
                            FlowLayout(items: model.allTechStacks) { techStack in
                                Button(action: {
                                    Haptics.shared.vibrateIfEnabled()
                                    model.onSelectTechStack(techStack)
                                }) {
                                    HStack(spacing: 4) {
                                        Text(techStack)
                                            .font(.callout)
                                            .foregroundColor(.primary)
                                        if model.selectedTechStacks.contains(techStack) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(AIStudioPalette.violet)
                                        }
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .glassCapsule(
                                        tint: model.selectedTechStacks.contains(techStack) ? AIStudioPalette.violet.opacity(0.25) : nil,
                                        interactive: true,
                                        fallback: model.selectedTechStacks.contains(techStack) ? AIStudioPalette.violet.opacity(0.15) : AIStudioPalette.surface
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .padding()
                        }
                        .navigationTitle("Filter by Tech Stack")
                        .navigationBarTitleDisplayMode(.inline)
                    }
                    .presentationDetents([.medium, .large])
                }
                .sheet(isPresented: Binding($model.route.showingAddVibePrompt)) {
                    VibePromptFormView(model: VibePromptFormModel { _ in model.route = nil })
                }
                .sheet(item: $model.route.addingDraft, id: \.self) { draft in
                    VibePromptFormView(model: VibePromptFormModel(prompt: draft) { _ in model.route = nil })
                }
                .sheet(isPresented: Binding($model.route.generatingIdea), onDismiss: { model.onIdeaSheetDismissed() }) {
                    PromptIdeaSheet(
                        title: "New App Idea",
                        placeholder: "e.g. a habit tracker for plant care",
                        examples: [
                            String(localized: "A budget tracker"),
                            String(localized: "A word puzzle game"),
                            String(localized: "A recipe organizer"),
                            String(localized: "A pomodoro timer"),
                        ]
                    ) { topic in
                        try await model.generateIdea(about: topic)
                    }
                }
                .sheet(item: $model.route.customizing, id: \.self) { vibePrompt in
                    PromptCustomizeView(title: vibePrompt.app, prompt: vibePrompt.prompt) {
                        VibePromptUsage.record(vibePromptID: vibePrompt.id)
                    }
                }
                .sheet(item: $model.route.editingPrompt, id: \.self) { prompt in
                    VibePromptFormView(model: VibePromptFormModel(prompt: VibePrompt.Draft(prompt)) { _ in model.route = nil })
                }
            }
        }
    }
}

#Preview {
    VibePromptListView()
}
