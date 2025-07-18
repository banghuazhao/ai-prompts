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

    var body: some View {
        NavigationView {
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
                        Toggle("Is for Developers", isOn: $model.prompt.forDevs)
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
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { model.onTapSave() }) {
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
        }
    }
}

#Preview {
    PromptFormView(
        model: PromptFormModel()
    )
}
