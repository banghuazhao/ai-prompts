import SharingGRDB
import SwiftUI
import SwiftUINavigation

@Observable
@MainActor
class PromptFormModel {
    @ObservationIgnored
    @Dependency(\.defaultDatabase) var database

    var prompt: Prompt.Draft

    let isEdit: Bool
    let onUpsert: ((Prompt) -> Void)?

    init(
        prompt: Prompt.Draft = Prompt.Draft(),
        onUpsert: ((Prompt) -> Void)? = nil
    ) {
        self.prompt = prompt
        self.onUpsert = onUpsert
        isEdit = prompt.id != nil
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

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Prompt Details")) {
                    TextField("Act/Role (e.g., 'Act as a iOS Developer')", text: $model.prompt.act)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    TextField("Prompt Text", text: $model.prompt.prompt, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(5 ... 10)

                    Toggle("Is for Developers", isOn: $model.prompt.forDevs)
                }
            }
            .navigationTitle(
                model.isEdit ?
                    "Edit Prompt" :
                    "Add Prompt"
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
                    .disabled(model.prompt.act.isEmpty || model.prompt.prompt.isEmpty)
                }
            }
        }
    }
}

#Preview {
    PromptFormView(
        model: PromptFormModel()
    )
}
