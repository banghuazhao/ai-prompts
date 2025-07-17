import SwiftUI

struct VibePromptDetailView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss

    let vibePrompt: VibePrompt
    @State private var showingEditVibePrompt = false
    @State private var showingDeleteAlert = false
    @State private var copiedToClipboard = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(vibePrompt.app)
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Spacer()

                        Button(action: {
                        }) {
                            Image(systemName: vibePrompt.isFavorite ? "heart.fill" : "heart")
                                .foregroundColor(vibePrompt.isFavorite ? .red : .gray)
                                .font(.title2)
                        }
                    }

                    HStack {
                        Image(systemName: "person.circle")
                        Text("By \(vibePrompt.contributor)")
                    }
                    .foregroundColor(.secondary)
                    .font(.caption)
                }

                Divider()

                // Tech Stack
//                VStack(alignment: .leading, spacing: 10) {
//                    Text("Tech Stack")
//                        .font(.headline)
//
//                    LazyVGrid(columns: [
//                        GridItem(.adaptive(minimum: 100)),
//                    ], spacing: 8) {
//                        ForEach(vibePrompt.techStackArray, id: \.self) { tech in
//                            Text(tech)
//                                .font(.caption)
//                                .padding(.horizontal, 8)
//                                .padding(.vertical, 4)
//                                .background(Color.blue.opacity(0.1))
//                                .foregroundColor(.blue)
//                                .cornerRadius(8)
//                        }
//                    }
//                }

                Divider()

                // Prompt Content
                VStack(alignment: .leading, spacing: 15) {
                    Text("Prompt")
                        .font(.headline)

                    Text(vibePrompt.prompt)
                        .font(.body)
                        .lineSpacing(4)
                }

                // Action Buttons
                VStack(spacing: 10) {
                    Button(action: {
                        UIPasteboard.general.string = vibePrompt.prompt
                        copiedToClipboard = true

                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copiedToClipboard = false
                        }
                    }) {
                        HStack {
                            Image(systemName: copiedToClipboard ? "checkmark" : "doc.on.doc")
                            Text(copiedToClipboard ? "Copied!" : "Copy Prompt")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }

                    HStack(spacing: 10) {
                        Button(action: {
                            showingEditVibePrompt = true
                        }) {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Edit")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }

                        Button(action: {
                            showingDeleteAlert = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditVibePrompt) {
            EditVibePromptView(vibePrompt: vibePrompt)
        }
        .alert("Delete Vibe Prompt", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this vibe prompt? This action cannot be undone.")
        }
    }
}

struct EditVibePromptView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss

    let vibePrompt: VibePrompt

    @State private var app: String
    @State private var prompt: String
    @State private var contributor: String
    @State private var techstack: String

    init(vibePrompt: VibePrompt) {
        self.vibePrompt = vibePrompt
        _app = State(initialValue: vibePrompt.app)
        _prompt = State(initialValue: vibePrompt.prompt)
        _contributor = State(initialValue: vibePrompt.contributor)
        _techstack = State(initialValue: vibePrompt.techstack)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("App Details")) {
                    TextField("App Name", text: $app)
                    TextField("Contributor", text: $contributor)
                    TextField("Tech Stack (comma-separated)", text: $techstack)
                }

                Section(header: Text("Prompt")) {
                    TextEditor(text: $prompt)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Edit Vibe Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let updatedVibePrompt = VibePrompt(
                            id: 0,
                            app: app,
                            prompt: prompt,
                            contributor: contributor,
                            techstack: techstack
                        )
                        
                        dismiss()
                    }
                    .disabled(app.isEmpty || prompt.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        VibePromptDetailView(vibePrompt: VibePrompt(
            id: 0,
            app: "Test App",
            prompt: "This is a test vibe prompt content.",
            contributor: "Test Contributor",
            techstack: "Swift, SwiftUI, iOS"
        ))
        .environmentObject(DataManager())
    }
}
