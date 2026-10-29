import SwiftUI
import SwiftUINavigation

struct VibePromptListRow: View {
    @Bindable var model: VibePromptListModel
    let vibePrompt: VibePrompt

    var body: some View {
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
}
