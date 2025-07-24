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
        if let url = Bundle.main.url(forResource: "vibeprompts", withExtension: "csv"),
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
            if let url = Bundle.main.url(forResource: "vibeprompts", withExtension: "csv"),
               let content = try? String(contentsOf: url) {
                let generated = generator.generatePrompt()
                let draft = VibePrompt.Draft(app: "AI Generated App", prompt: generated)
                route = .showingAddMarkovPrompt(draft)
            } else {
                let draft = VibePrompt.Draft(app: "AI Generated App", prompt: "Failed to load corpus.")
                route = .showingAddMarkovPrompt(draft)
            }
        } else {
            let draft = VibePrompt.Draft(app: "AI Generated App", prompt: "Failed to load corpus.")
            route = .showingAddMarkovPrompt(draft)
        }
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
                    if !model.selectedTechStacks.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(model.selectedTechStacks, id: \.self) { techStack in
                                    Button(action: {
                                        Haptics.shared.vibrateIfEnabled()
                                        model.onDeselectTechStack(techStack)
                                    }) {
                                        HStack(spacing: 4) {
                                            Text(techStack)
                                                .font(.callout)
                                                .foregroundColor(.blue)
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.blue)
                                        }
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                        .background(Color.blue.opacity(0.15))
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
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
                    }
                }
                .scrollDismissesKeyboard(.immediately)
                .listStyle(.plain)
                .searchable(text: $model.searchText, prompt: "Search prompts")
                .navigationTitle("Vibe Prompts")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Menu {
                            Picker("Sort", selection: $model.sortOption) {
                                ForEach(VibePromptListModel.SortOption.allCases) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        } label: {
                            Label("Sort", systemImage: model.isDefault ? "arrow.up.arrow.down" : "arrow.up.arrow.down.circle.fill")
                        }
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
                            model.route = .showingAddVibePrompt
                        }) {
                            Image(systemName: "plus")
                        }
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
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(model.selectedTechStacks.contains(techStack) ? Color.blue.opacity(0.15) : Color(.systemGray6))
                                    .clipShape(Capsule())
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
