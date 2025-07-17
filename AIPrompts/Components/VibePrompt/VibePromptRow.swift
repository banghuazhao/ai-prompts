import SwiftUI

struct VibePromptRowView: View {
    let vibePrompt: VibePrompt
    let onFavorite: () -> Void
    
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
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            
            Text(vibePrompt.prompt)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "person.circle")
                        .font(.caption)
                    Text(vibePrompt.contributor)
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                
                Spacer()
                
//                Text("\(vibePrompt.techStackArray.count) tech")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
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
