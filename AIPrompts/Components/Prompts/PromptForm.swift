import Dependencies
import SharingGRDB
import SwiftUI
import SwiftUINavigation

@Observable
@MainActor
class PromptFormModel {
    @ObservationIgnored
    @Dependency(\.defaultDatabase) var database

    @ObservationIgnored
    @FetchAll(PromptCategory.all, animation: .default) var allCategories

    var prompt: Prompt.Draft

    let isEdit: Bool
    let onUpsert: ((Prompt) -> Void)?

    @CasePathable
    enum Route {
        case selectCategory
    }

    var route: Route?

    var isSuggestingDetails = false
    var detailsFailure: OnDeviceAIFailure?

    var canSuggestDetails: Bool {
        OnDeviceAI.status == .available && !prompt.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(
        prompt: Prompt.Draft = Prompt.Draft(),
        onUpsert: ((Prompt) -> Void)? = nil
    ) {
        self.prompt = prompt
        self.onUpsert = onUpsert
        isEdit = prompt.id != nil
    }

    /// Fills in the title, category and developer flag from the prompt text.
    func onSuggestDetails() {
        guard #available(iOS 26.0, *) else { return }
        let text = prompt.prompt
        let categories = allCategories
        isSuggestingDetails = true
        detailsFailure = nil
        Task {
            do {
                let details = try await PromptAssistant.suggestDetails(for: text, categoryTitles: categories.map(\.title))
                withAnimation {
                    prompt.act = details.title
                    if let categoryTitle = details.categoryTitle {
                        prompt.categoryID = categories.first { $0.title == categoryTitle }?.id
                    }
                    prompt.forDevs = details.isForDevelopers
                }
            } catch {
                detailsFailure = OnDeviceAIFailure(error)
            }
            isSuggestingDetails = false
        }
    }

    func onTapSelectCategory() {
        route = .selectCategory
    }

    func onSelectCategory(_ category: PromptCategory?) {
        prompt.categoryID = category?.id
        Task {
            route = nil
        }
    }

    func onTapSave() {
        withErrorReporting {
            let newPrompt =
                try database.write { db in
                    try Prompt
                        .upsert {
                            prompt
                        }
                        .returning { $0 }
                        .fetchOne(db)
                }

            if let newPrompt {
                onUpsert?(newPrompt)
            }
        }
    }
}

struct PromptFormView: View {
    @State var model: PromptFormModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("showContextEngineeringTips") private var showContextEngineeringTips: Bool = true
    @State private var showAnalyzerFeedback: Bool = false
    @State private var analyzerIssues: [PromptIssue] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    introduction
                    promptDetailsCard
                    organizationCard

                    if showAnalyzerFeedback {
                        analyzerFeedbackCard
                    }
                    if showContextEngineeringTips {
                        contextTipsCard
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(AIStudioPalette.canvas.ignoresSafeArea())
            .navigationTitle(
                model.isEdit ?
                    "Edit Prompt" :
                    "Add Prompt"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        Haptics.shared.vibrateIfEnabled()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Haptics.shared.vibrateIfEnabled()
                        model.onTapSave()
                    }
                    .font(.headline)
                    .glassButtonStyle(prominent: true)
                    .tint(AIStudioPalette.violet)
                    .disabled(model.prompt.act.isEmpty || model.prompt.prompt.isEmpty)
                }
            }
            .sheet(isPresented: Binding($model.route.selectCategory)) {
                CategoryFormView(
                    model: CategoryFormModel(
                        selectedCategory: model.prompt.categoryID,
                        onSelect: { category in
                            model.onSelectCategory(category)
                        }
                    )
                )
                .presentationDetents([.fraction(0.7), .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var introduction: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.title2)
                .foregroundStyle(AIStudioPalette.cyan)
                .frame(width: 48, height: 48)
                .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Group {
                    if model.isEdit {
                        Text("Refine your prompt")
                    } else {
                        Text("Create a prompt")
                    }
                }
                .font(.caption.bold())
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(AIStudioPalette.cyan)
                Text("Your ideas, ready for any AI.")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AIStudioPalette.heroGradient, in: RoundedRectangle(cornerRadius: 24))
    }

    private var promptDetailsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Prompt Details", systemImage: "text.quote")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Title or role")
                    .font(.subheadline.bold())
                TextField("e.g. Act as an iOS developer", text: $model.prompt.act)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 52)
                    .background(AIStudioPalette.canvas, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AIStudioPalette.border))
                    .accessibilityLabel("Title or role")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Prompt Text")
                    .font(.subheadline.bold())
                TextField("Describe what the AI should do", text: $model.prompt.prompt, axis: .vertical)
                    .font(.body)
                    .lineLimit(5 ... 10)
                    .padding(14)
                    .background(AIStudioPalette.canvas, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AIStudioPalette.border))
                    .accessibilityLabel("Prompt Text")
                Label("Tip: wrap words in {{double braces}} (e.g. {{topic}}) to make fill-in-the-blank variables.", systemImage: "lightbulb")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if model.canSuggestDetails {
                AISuggestButton(
                    title: "Suggest Title & Category",
                    isLoading: model.isSuggestingDetails,
                    failure: model.detailsFailure
                ) {
                    model.onSuggestDetails()
                }
            }

            if !model.prompt.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    analyzerIssues = PromptAnalyzer.analyze(model.prompt.prompt)
                    showAnalyzerFeedback = true
                } label: {
                    Label("Improve Prompt", systemImage: "wand.and.stars")
                        .font(.subheadline.bold())
                        .foregroundStyle(AIStudioPalette.violet)
                        .frame(minHeight: 44)
                        .padding(.horizontal, 14)
                        .background(AIStudioPalette.violet.opacity(0.10), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AIStudioPalette.surface, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(AIStudioPalette.border))
    }

    private var organizationCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Organize", systemImage: "square.grid.2x2")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(.subheadline.bold())
                Button(action: model.onTapSelectCategory) {
                    HStack(spacing: 12) {
                        Image(systemName: "square.grid.2x2.fill")
                            .foregroundStyle(AIStudioPalette.violet)
                        if let selectedCategory = model.allCategories.first(where: { $0.id == model.prompt.categoryID }) {
                            Text(selectedCategory.displayTitle)
                                .foregroundStyle(.primary)
                        } else {
                            Text("All Categories")
                                .foregroundStyle(.primary)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                    }
                    .font(.body)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 52)
                    .background(AIStudioPalette.canvas, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AIStudioPalette.border))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Category")
                .accessibilityValue(
                    model.allCategories.first(where: { $0.id == model.prompt.categoryID })?.displayTitle ?? String(localized: "All Categories")
                )
            }

            Toggle("Is for Developers", isOn: $model.prompt.forDevs)
                .font(.body)
                .tint(AIStudioPalette.violet)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AIStudioPalette.surface, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(AIStudioPalette.border))
    }

    private var analyzerFeedbackCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Label("Prompt Improvement Suggestions", systemImage: "wand.and.stars")
                    .font(.headline)
                Spacer(minLength: 8)
                Button("Dismiss suggestions", systemImage: "xmark") {
                    showAnalyzerFeedback = false
                }
                .labelStyle(.iconOnly)
                .frame(width: 44, height: 44)
                .background(AIStudioPalette.canvas, in: Circle())
            }
            if analyzerIssues.isEmpty {
                Text("No major issues detected. Your prompt looks good!")
                    .font(.footnote)
                    .foregroundStyle(.primary)
            } else {
                ForEach(analyzerIssues) { issue in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• \(issue.type): \(issue.description)")
                            .font(.footnote)
                        if let suggestion = issue.suggestion {
                            Text("Suggestion: \(suggestion)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AIStudioPalette.surface, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(AIStudioPalette.border))
    }

    private var contextTipsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Label("Context Engineering Tips", systemImage: "lightbulb")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Button("Dismiss tips", systemImage: "xmark") {
                    withAnimation {
                        showContextEngineeringTips = false
                    }
                }
                .labelStyle(.iconOnly)
                .frame(width: 44, height: 44)
                .background(AIStudioPalette.canvas, in: Circle())
            }
            Text("• Be clear and specific about the task.")
            Text("• Include only necessary information.")
            Text("• Use structure (lists, JSON, etc.) for clarity.")
            Text("• Break complex tasks into steps.")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AIStudioPalette.violet.opacity(0.08), in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(AIStudioPalette.border))
    }
}

#Preview {
    let _ = prepareDependencies {
        $0.defaultDatabase = try! appDatabase()
    }

    PromptFormView(
        model: PromptFormModel()
    )
}
