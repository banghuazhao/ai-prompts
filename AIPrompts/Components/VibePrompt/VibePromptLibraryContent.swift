import SwiftUI
import SwiftUINavigation

struct VibePromptLibraryContent: View {
    @Bindable var model: VibePromptListModel

    var body: some View {
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
                VibePromptListRow(model: model, vibePrompt: vibePrompt)
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
        .toolbar { VibePromptListToolbar(model: model) }
    }
}
