//
// Created by Banghua Zhao on 17/07/2025
// Copyright Apps Bay Limited. All rights reserved.
//

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

    var body: some View {
        NavigationView {
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
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(.systemGray6))
                            )
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
                    "Edit Vibe Prompt" :
                    "Add Vibe Prompt"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { model.onTapSave() }) {
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
