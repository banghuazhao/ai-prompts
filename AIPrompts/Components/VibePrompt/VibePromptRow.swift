import SwiftUI

struct VibePromptRowView: View {
    let vibePrompt: VibePrompt
    let onFavorite: () -> Void

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(vibePrompt.app)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                Spacer()

                Button(action: {
                    onFavorite()
                }) {
                    Image(systemName: vibePrompt.isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(vibePrompt.isFavorite ? .red : .gray)
                }
                .buttonStyle(.plain)

                Button(action: {
                    UIPasteboard.general.string = vibePrompt.prompt
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

            Text(vibePrompt.prompt)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            // Tech Stack as badges
            if !vibePrompt.techstack.isEmpty {
                HStack(spacing: 8) {
                    ForEach(vibePrompt.techstackArray, id: \.self) { tech in
                        Text(tech)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.vertical, 4)
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
