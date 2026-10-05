import SwiftUI

struct VibePromptRowView: View {
    let vibePrompt: VibePrompt
    let onFavorite: () -> Void

    @State private var copied = false

    private var visibleTech: [String] {
        Array(vibePrompt.techstackArray.prefix(2))
    }

    private var hiddenTechCount: Int {
        max(0, vibePrompt.techstackArray.count - visibleTech.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "laptopcomputer.and.iphone")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AIStudioPalette.violet)
                    .frame(width: 44, height: 44)
                    .background(AIStudioPalette.violet.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(vibePrompt.app)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if vibePrompt.isNew {
                        NewBadge()
                    }
                }

                Button {
                    Haptics.shared.vibrateIfEnabled()
                    onFavorite()
                } label: {
                    Image(systemName: vibePrompt.isFavorite ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundStyle(vibePrompt.isFavorite ? Color.red : Color.secondary)
                        .frame(width: 44, height: 44)
                        .background(vibePrompt.isFavorite ? Color.red.opacity(0.10) : AIStudioPalette.canvas, in: Circle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(vibePrompt.isFavorite ? "Remove from favorites" : "Add to favorites")
            }

            Text(vibePrompt.prompt)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            HStack(spacing: 6) {
                ForEach(visibleTech, id: \.self) { tech in
                    BadgeView(icon: nil, text: tech)
                }

                if hiddenTechCount > 0 {
                    Text("+\(hiddenTechCount)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(hiddenTechCount) more technologies")
                }

                Spacer(minLength: 0)

                Button {
                    Haptics.shared.vibrateIfEnabled()
                    PromptActions.copy(vibePrompt.prompt)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(copied ? Color.green : AIStudioPalette.violet)
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
        VibePromptRowView(vibePrompt: VibePrompt(
            id: 0,
            app: "Todo List",
            prompt: "Create a responsive todo app with HTML5, CSS3 and vanilla JavaScript.",
            contributor: "f",
            techstack: "HTML,CSS,JavaScript"
        )) {}
        VibePromptRowView(vibePrompt: VibePrompt(
            id: 0,
            app: "Weather Dashboard",
            prompt: "Build a comprehensive weather dashboard using HTML5, CSS3, JavaScript and the OpenWeatherMap API.",
            contributor: "f",
            techstack: "HTML,CSS,JavaScript,API"
        )) {}
    }
    .environmentObject(DataManager())
}
