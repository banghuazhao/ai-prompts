import SwiftUI
import SwiftUINavigation

struct VibePromptListToolbar: ToolbarContent {
    @Bindable var model: VibePromptListModel

    var body: some ToolbarContent {
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
}
