import Dependencies
import SharingGRDB
import SwiftUI
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
        var id: String { self.rawValue }
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

    @CasePathable
    enum Route {
        case showingAddVibePrompt
        case editingPrompt(VibePrompt)
        case showingDeleteAlert(VibePrompt)
        case isFilterTechShareSheetPresented
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
                                Button(action: { model.onEdit(vibePrompt) }) {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button(action: { model.onFavorite(vibePrompt) }) {
                                    Label(vibePrompt.isFavorite ? "Unfavorite" : "Favorite", systemImage: vibePrompt.isFavorite ? "heart.slash" : "heart")
                                }
                                Button(role: .destructive, action: { model.onDeleteRequest(vibePrompt) }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .searchable(text: $model.searchText, prompt: "Search prompts")
                .navigationTitle("Vibe Prompts")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        HStack {
                            Menu {
                                Picker("Sort", selection: $model.sortOption) {
                                    ForEach(VibePromptListModel.SortOption.allCases) { option in
                                        Text(option.rawValue).tag(option)
                                    }
                                }
                            } label: {
                                Label("Sort", systemImage: model.isDefault ? "arrow.up.arrow.down" : "arrow.up.arrow.down.circle.fill")
                            }
                            Button(action: {
                                model.onTapFilterTechStackSheet()
                            }) {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                            }
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            model.route = .showingAddVibePrompt
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: Binding($model.route.isFilterTechShareSheetPresented)) {
                    NavigationView {
                        ScrollView {
                            FlowLayout(items: model.allTechStacks, spacing: 8) { techStack in
                                Button(action: {
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
                .sheet(item: $model.route.editingPrompt, id: \ .self) { prompt in
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
