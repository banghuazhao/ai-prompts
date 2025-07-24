//
// Created by Banghua Zhao on 17/07/2025
// Copyright Apps Bay Limited. All rights reserved.
//

import Dependencies
import SharingGRDB
import SwiftUI
import SwiftUINavigation

@Observable
@MainActor
class VibePromptFormModel {
    @ObservationIgnored
    @Dependency(\.defaultDatabase) var database

    var prompt: VibePrompt.Draft
    let isEdit: Bool
    let onUpsert: ((VibePrompt) -> Void)?

    init(
        prompt: VibePrompt.Draft = VibePrompt.Draft(),
        onUpsert: ((VibePrompt) -> Void)? = nil
    ) {
        self.prompt = prompt
        self.onUpsert = onUpsert
        isEdit = prompt.id != nil
    }

    func onTapSave() {
        withErrorReporting {
            prompt.modifiedDate = Date()
            let newPrompt =
                try database.write { db in
                    try VibePrompt
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

struct VibePromptFormView: View {
    @State var model: VibePromptFormModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("showContextEngineeringTips") private var showContextEngineeringTips: Bool = true
    @State private var showAnalyzerFeedback: Bool = false
    @State private var analyzerIssues: [PromptIssue] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // App Details Card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("App Details")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 2)
                        TextField("App Name", text: $model.prompt.app)
                            .textFieldStyle(.roundedBorder)
                        TextField("Contributor (optional)", text: $model.prompt.contributor)
                            .textFieldStyle(.roundedBorder)
                        Text("Enter your GitHub username (e.g., banghuazhao, which will link to https://github.com/banghuazhao). Optional.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Tech Stack (comma-separated, optional)", text: $model.prompt.techstack)
                            .textFieldStyle(.roundedBorder)
                        Text("Example: Swift, SwiftUI, iOS. Optional.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                    )

                    // Prompt Card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Prompt")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 2)
                        TextEditor(text: $model.prompt.prompt)
                            .frame(minHeight: 300)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(.systemGray6))
                            )
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
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                    )

                    if showContextEngineeringTips {
                        VStack(alignment: .leading, spacing: AppSpacing.small) {
                            HStack {
                                Text("Context Engineering Tips")
                                    .font(AppFont.headline)
                                Spacer()
                                Button(
                                    action: {
                                        withAnimation {
                                            showContextEngineeringTips = false
                                        }
                                    }
                                ) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            Text("• Be clear and specific about the app or use case.")
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
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(
                model.isEdit ?
                    "Edit Vibe Prompt" :
                    "Add Vibe Prompt"
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
                            .background(model.prompt.app.isEmpty || model.prompt.prompt.isEmpty ? Color(.systemGray4) : Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(model.prompt.app.isEmpty || model.prompt.prompt.isEmpty)
                }
            }
        }
    }
}
