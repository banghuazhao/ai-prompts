import SwiftUI
import SwiftUINavigation

struct VibePromptSheets: ViewModifier {
    @Bindable var model: VibePromptListModel

    func body(content: Content) -> some View {
        content
        .sheet(isPresented: Binding($model.route.isFilterTechShareSheetPresented)) {
            VibePromptTechStackFilter(model: model)
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
