//
// Created by Banghua Zhao on 27/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// "AI Prompts" in the share sheet: saves shared text as a new prompt.
///
/// The extension can't open the app's database, so the prompt waits in the shared inbox and the
/// app adds it to the library the next time it comes to the front.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        Task { @MainActor in
            let text = await sharedText() ?? ""
            showForm(for: ImportedPrompt(text: text) ?? ImportedPrompt(title: "", prompt: ""))
        }
    }

    private func showForm(for imported: ImportedPrompt) {
        let form = ShareFormView(
            title: imported.title,
            prompt: imported.prompt,
            onCancel: { [weak self] in
                self?.extensionContext?.cancelRequest(withError: CocoaError(.userCancelled))
            },
            onSave: { [weak self] prompt in
                try SharedInbox.append(prompt)
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
        )
        let host = UIHostingController(rootView: form)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        host.didMove(toParent: self)
    }

    /// The first piece of text in what was shared.
    private func sharedText() async -> String? {
        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        let providers = items.flatMap { $0.attachments ?? [] }
        let textType = UTType.plainText.identifier
        for provider in providers where provider.hasItemConformingToTypeIdentifier(textType) {
            guard let item = try? await provider.loadItem(forTypeIdentifier: textType, options: nil) else { continue }
            if let text = item as? String {
                return text
            }
            if let data = item as? Data, let text = String(data: data, encoding: .utf8) {
                return text
            }
            if let url = item as? URL, let text = try? String(contentsOf: url, encoding: .utf8) {
                return text
            }
        }
        return items.first?.attributedContentText?.string
    }
}

/// Lets the user check the title and text before saving.
struct ShareFormView: View {
    @State var title: String
    @State var prompt: String
    let onCancel: () -> Void
    let onSave: (ImportedPrompt) throws -> Void

    @State private var showsSaveFailure = false

    private var trimmedPrompt: String {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Optional", text: $title)
                }
                Section {
                    TextEditor(text: $prompt)
                        .frame(minHeight: 200)
                } header: {
                    Text("Prompt")
                } footer: {
                    Text("It's added to your library the next time you open AI Prompts.")
                }
            }
            .navigationTitle("Add to AI Prompts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(trimmedPrompt.isEmpty)
                }
            }
            .alert("Couldn't Save the Prompt", isPresented: $showsSaveFailure) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please try again.")
            }
        }
    }

    private func save() {
        let imported = ImportedPrompt(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            prompt: trimmedPrompt
        )
        do {
            try onSave(imported)
        } catch {
            showsSaveFailure = true
        }
    }
}
