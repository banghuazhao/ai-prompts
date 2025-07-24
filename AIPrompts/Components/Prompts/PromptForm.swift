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

    init(
        prompt: Prompt.Draft = Prompt.Draft(),
        onUpsert: ((Prompt) -> Void)? = nil
    ) {
        self.prompt = prompt
        self.onUpsert = onUpsert
        isEdit = prompt.id != nil
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
            prompt.modifiedDate = Date()
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
                VStack(spacing: 24) {
                    // Prompt Details Card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Prompt Details")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 2)
                        TextField("Act/Role (e.g., 'Act as a iOS Developer')", text: $model.prompt.act)
                            .textFieldStyle(.roundedBorder)
                        TextField("Prompt Text", text: $model.prompt.prompt, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(5 ... 10)
                        // Category Selection
                        HStack {
                            Text("Category")

                            Spacer()

                            Button {
                                model.onTapSelectCategory()
                            } label: {
                                HStack {
                                    if let selectedCategory = model.allCategories.first(where: { $0.id == model.prompt.categoryID }) {
                                        Text(selectedCategory.title)
                                    } else {
                                        Text("💬 All")
                                    }
                                }
                            }
                        }
                        Toggle("Is for Developers", isOn: $model.prompt.forDevs)
                        // --- Analyzer Button ---
                        if !model.prompt.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button(action: {
                                analyzerIssues = PromptAnalyzer.analyze(model.prompt.prompt)
                                showAnalyzerFeedback = true
                            }) {
                                Label("Improve Prompt", systemImage: "wand.and.stars")
                                    .font(.subheadline)
                                    .padding(8)
                                    .background(Color.accentColor.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            .padding(.top, 4)
                        }
                        // --- Analyzer Feedback Panel ---
                        if showAnalyzerFeedback {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Prompt Improvement Suggestions")
                                        .font(.headline)
                                    Spacer()
                                    Button(action: { showAnalyzerFeedback = false }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                if analyzerIssues.isEmpty {
                                    Text("No major issues detected. Your prompt looks good!")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                } else {
                                    ForEach(analyzerIssues) { issue in
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("• \(issue.type): \(issue.description)")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                            if let suggestion = issue.suggestion {
                                                Text("  Suggestion: \(suggestion)")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(8)
                            .background(Color.yellow.opacity(0.1))
                            .cornerRadius(10)
                        }

                        if showContextEngineeringTips {
                            VStack(alignment: .leading, spacing: AppSpacing.small) {
                                HStack {
                                    Text("Context Engineering Tips")
                                        .font(AppFont.headline)
                                    Spacer()
                                    Button{
                                        withAnimation {
                                            showContextEngineeringTips = false
                                        }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                Text("• Be clear and specific about the task.")
                                    .font(AppFont.caption)
                                Text("• Include only necessary information.")
                                    .font(AppFont.caption)
                                Text("• Use structure (lists, JSON, etc.) for clarity.")
                                    .font(AppFont.caption)
                                Text("• Break complex tasks into steps.")
                                    .font(AppFont.caption)
                            }
                            .appInfoSection()
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                    )
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
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
                    Button(action: {
                        Haptics.shared.vibrateIfEnabled()
                        model.onTapSave()
                    }) {
                        Text("Save")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(model.prompt.act.isEmpty || model.prompt.prompt.isEmpty ? Color(.systemGray4) : Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
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
}

#Preview {
    let _ = prepareDependencies {
        $0.defaultDatabase = try! appDatabase()
    }

    PromptFormView(
        model: PromptFormModel()
    )
}
