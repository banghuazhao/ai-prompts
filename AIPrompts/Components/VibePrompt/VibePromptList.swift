import Dependencies
import SharingGRDB
import SwiftUI
import SwiftUIFlowLayout
import SwiftUINavigation

@Observable
@MainActor
class VibePromptListModel {
    var searchText = ""
    var showingAddPrompt = false
    enum SortOption: String, CaseIterable, Identifiable {
        case modifiedDate = "Modified Date"
        case title = "Title"
        case characterLengthAsc = "Character Length ↑"
        case characterLengthDesc = "Character Length ↓"
        var id: String { rawValue }
    }

    var sortOption: SortOption = .modifiedDate
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
            app: "AI Generated App",
            prompt: generated.isEmpty ? "Failed to load corpus." : generated
        )
        route = .showingAddMarkovPrompt(draft)
    }

    @CasePathable
    enum Route {
        case showingAddVibePrompt
        case editingPrompt(VibePrompt)
        case showingDeleteAlert(VibePrompt)
        case isFilterTechShareSheetPresented
        case showingAddMarkovPrompt(VibePrompt.Draft)
    }

    var route: Route?

    var allTechStacks: [String] {
        Array(Set(vibePrompts.flatMap { $0.techstackArray }))
            .sorted()
    }

    var selectedTechStacks: [String] = []

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
        if !searchText.isEmpty {
            new = searchVibePrompts(vibePrompts: new, query: searchText)
        }
        // Sort
        switch sortOption {
        case .modifiedDate:
            new = new.sorted { $0.modifiedDate > $1.modifiedDate }
        case .title:
            new = new.sorted { $0.app.localizedCaseInsensitiveCompare($1.app) == .orderedAscending }
        case .characterLengthAsc:
            new = new.sorted { $0.prompt.count < $1.prompt.count }
        case .characterLengthDesc:
            new = new.sorted { $0.prompt.count > $1.prompt.count }
        }
        return new
    }

    func searchVibePrompts(vibePrompts: [VibePrompt], query: String) -> [VibePrompt] {
        guard !query.isEmpty else { return vibePrompts }

        let lowercasedQuery = query.lowercased()
        return vibePrompts.filter { vibePrompt in
            vibePrompt.app.lowercased().contains(lowercasedQuery) ||
                vibePrompt.prompt.lowercased().contains(lowercasedQuery)
        }
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
                        Text("\(model.filteredVibePrompts.count)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 22, bottom: 8, trailing: 22))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    ForEach(model.filteredVibePrompts) { vibePrompt in
                        NavigationLink(destination: VibePromptDetailView(model: VibePromptDetailModel(vibePrompt: vibePrompt))) {
                            VibePromptRowView(vibePrompt: vibePrompt) {
                                model.onFavorite(vibePrompt)
                            }
                            .contextMenu {
                                Button(action: {
                                    Haptics.shared.vibrateIfEnabled()
                                    model.onEdit(vibePrompt)
                                }) {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button(action: {
                                    Haptics.shared.vibrateIfEnabled()
                                    model.onFavorite(vibePrompt)
                                }) {
                                    Label(vibePrompt.isFavorite ? "Unfavorite" : "Favorite", systemImage: vibePrompt.isFavorite ? "heart.slash" : "heart")
                                }
                                Button(role: .destructive, action: {
                                    Haptics.shared.vibrateIfEnabled()
                                    model.onDeleteRequest(vibePrompt)
                                }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 3, leading: 18, bottom: 11, trailing: 18))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }

                    if model.filteredVibePrompts.isEmpty {
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
                            model.route = .showingAddVibePrompt
                        }) {
                            Image(systemName: "plus")
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
                .sheet(item: $model.route.showingAddMarkovPrompt, id: \.self) { draft in
                    VibePromptFormView(model: VibePromptFormModel(prompt: draft) { _ in model.route = nil })
                }
                .sheet(item: $model.route.editingPrompt, id: \.self) { prompt in
                    VibePromptFormView(model: VibePromptFormModel(prompt: VibePrompt.Draft(prompt)) { _ in model.route = nil })
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
}

#Preview {
    VibePromptListView()
}
