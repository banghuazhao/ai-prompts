import SharingGRDB
import SwiftUI

struct PromptRowView: View {
    let prompt: Prompt
    let onFavorite: () -> Void

    @State private var copied = false

    @Dependency(\.defaultDatabase) private var database

    var category: PromptCategory? {
        try? database.read { db in
            try? PromptCategory
                .all
                .where { $0.id.is(prompt.categoryID) }
                .fetchOne(db)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(prompt.act)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                Spacer()

                Button(action: {
                    Haptics.shared.vibrateIfEnabled()
                    onFavorite()
                }) {
                    Image(systemName: prompt.isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(prompt.isFavorite ? .red : .gray)
                }
                .buttonStyle(.plain)

                Button(action: {
                    Haptics.shared.vibrateIfEnabled()
                    UIPasteboard.general.string = prompt.prompt
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                }) {
                    ZStack {
                        Image(systemName: "doc.on.doc")
                            .opacity(copied ? 0 : 1)
                        Image(systemName: "checkmark")
                            .opacity(copied ? 1 : 0)
                    }
                    .foregroundColor(copied ? .green : .gray)
                }
                .buttonStyle(.plain)
            }

            Text(prompt.prompt)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            HStack {
                VStack(alignment: .leading) {
                    if let category {
                        BadgeView(icon: nil, text: category.title)
                    }

                    if prompt.forDevs {
                        BadgeView(icon: "laptopcomputer", text: "For Developers")
                    }
                }

                Spacer()

                Text("\(prompt.prompt.count) characters")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                LinearGradient(
                    colors: [Color.purple.opacity(0.10), Color.cyan.opacity(0.08), Color.pink.opacity(0.08), Color.white.opacity(0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.white.opacity(0.07), radius: 3, x: -3, y: -3)
        .shadow(color: Color.black.opacity(0.10), radius: 3, x: 3, y: 3)
    }
}

#Preview {
    List {
        PromptRowView(prompt: Prompt(
            id: 1,
            act: "JavaScript Console",
            prompt: "I want you to act as a javascript console. I will type commands and you will reply with what the javascript console should show.",
            forDevs: true
        ), onFavorite: {})
        PromptRowView(prompt: Prompt(
            id: 1,
            act: "English Translator",
            prompt: "I want you to act as an English translator, spelling corrector and improver.",
            forDevs: false
        ), onFavorite: {})
    }
    .environmentObject(DataManager())
}
