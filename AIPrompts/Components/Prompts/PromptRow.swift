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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: prompt.forDevs ? "chevron.left.forwardslash.chevron.right" : "text.quote")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AIStudioPalette.violet)
                    .frame(width: 44, height: 44)
                    .background(AIStudioPalette.violet.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(prompt.act)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if prompt.isNew {
                        NewBadge()
                    }
                }

                Button {
                    Haptics.shared.vibrateIfEnabled()
                    onFavorite()
                } label: {
                    Image(systemName: prompt.isFavorite ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundStyle(prompt.isFavorite ? .red : .secondary)
                        .frame(width: 44, height: 44)
                        .background(prompt.isFavorite ? Color.red.opacity(0.10) : AIStudioPalette.canvas, in: Circle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(prompt.isFavorite ? "Remove from favorites" : "Add to favorites")
            }

            Text(prompt.prompt)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            HStack(spacing: 8) {
                if let category {
                    BadgeView(icon: nil, text: category.title)
                } else if prompt.forDevs {
                    BadgeView(icon: "laptopcomputer", text: "For Developers")
                }

                Spacer(minLength: 8)

                Button {
                    Haptics.shared.vibrateIfEnabled()
                    PromptActions.copy(prompt.prompt)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(copied ? .green : AIStudioPalette.violet)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(AIStudioPalette.violet.opacity(0.09), in: Capsule())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(copied ? "Prompt copied" : "Copy prompt")
            }
        }
        .padding(16)
        .promptRowSurface()
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
