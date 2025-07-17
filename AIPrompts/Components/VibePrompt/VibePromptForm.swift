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
            Form {
                Section(header: Text("App Details")) {
                    TextField("App Name", text: $model.prompt.app)
                    TextField("Contributor", text: $model.prompt.contributor)
                    TextField("Tech Stack (comma-separated)", text: $model.prompt.techstack)
                }

                Section(header: Text("Prompt")) {
                    TextEditor(text: $model.prompt.prompt)
                        .frame(minHeight: 100)
                }
            }
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
                    Button("Save") {
                        model.onTapSave()
                    }
                    .disabled(model.prompt.app.isEmpty || model.prompt.prompt.isEmpty)
                }
            }
        }
    }
}
