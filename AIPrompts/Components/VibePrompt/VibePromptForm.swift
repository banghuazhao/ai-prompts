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

    var isSuggestingDetails = false
    var detailsFailure: OnDeviceAIFailure?

    var canSuggestDetails: Bool {
        OnDeviceAI.status == .available && !prompt.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(
        prompt: VibePrompt.Draft = VibePrompt.Draft(),
        onUpsert: ((VibePrompt) -> Void)? = nil
    ) {
        self.prompt = prompt
        self.onUpsert = onUpsert
        isEdit = prompt.id != nil
    }

    /// Fills in the app name and tech stack from the prompt text.
    func onSuggestDetails() {
        guard #available(iOS 26.0, *) else { return }
        let text = prompt.prompt
        isSuggestingDetails = true
        detailsFailure = nil
        Task {
            do {
                let details = try await PromptAssistant.suggestVibeDetails(for: text)
                withAnimation {
                    prompt.app = details.appName
                    prompt.techstack = details.techStack.joined(separator: ", ")
                }
            } catch {
                detailsFailure = OnDeviceAIFailure(error)
            }
            isSuggestingDetails = false
        }
    }

    func onTapSave() {
        withErrorReporting {
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
                VStack(alignment: .leading, spacing: 20) {
                    introduction
                    appDetailsCard
                    promptCard

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
                    Button("Save") {
                        Haptics.shared.vibrateIfEnabled()
                        model.onTapSave()
                    }
                    .font(.headline)
                    .glassButtonStyle(prominent: true)
                    .tint(AIStudioPalette.violet)
                    .disabled(model.prompt.app.isEmpty || model.prompt.prompt.isEmpty)
                }
            }
        }
    }

    private var introduction: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "curlybraces")
                .font(.title2)
                .foregroundStyle(AIStudioPalette.cyan)
                .frame(width: 48, height: 48)
                .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Group {
                    if model.isEdit {
                        Text("Refine your build")
                    } else {
                        Text("Create a vibe prompt")
                    }
                }
                .font(.caption.bold())
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(AIStudioPalette.cyan)
                Text("Define the app, then describe what to build.")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AIStudioPalette.heroGradient, in: RoundedRectangle(cornerRadius: 24))
    }

    private var appDetailsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("App Details", systemImage: "square.stack.3d.up")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("App Name")
                    .font(.subheadline.bold())
                TextField("Name your app", text: $model.prompt.app)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 52)
                    .background(AIStudioPalette.canvas, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AIStudioPalette.border))
                    .accessibilityLabel("App Name")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Contributor (optional)")
                    .font(.subheadline.bold())
                TextField("GitHub username", text: $model.prompt.contributor)
                    .font(.body)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .frame(minHeight: 52)
                    .background(AIStudioPalette.canvas, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AIStudioPalette.border))
                    .accessibilityLabel("Contributor")
                Text("Your GitHub username links to your profile (for example, banghuazhao).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Tech Stack (optional)")
                    .font(.subheadline.bold())
                TextField("Swift, SwiftUI, iOS", text: $model.prompt.techstack)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 52)
                    .background(AIStudioPalette.canvas, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AIStudioPalette.border))
                    .accessibilityLabel("Tech Stack")
                Text("Separate technologies with commas, for example Swift, SwiftUI, iOS.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AIStudioPalette.surface, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(AIStudioPalette.border))
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Prompt", systemImage: "text.quote")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Prompt Text")
                    .font(.subheadline.bold())
                TextEditor(text: $model.prompt.prompt)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 260)
                    .padding(10)
                    .background(AIStudioPalette.canvas, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AIStudioPalette.border))
                    .accessibilityLabel("Prompt Text")
                Label("Tip: wrap words in {{double braces}} (e.g. {{topic}}) to make fill-in-the-blank variables.", systemImage: "lightbulb")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if model.canSuggestDetails {
                AISuggestButton(
                    title: "Suggest App Name & Tech Stack",
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
            Text("• Be clear and specific about the app or use case.")
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
