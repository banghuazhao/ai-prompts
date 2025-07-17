import SwiftUI

struct PromptRowView: View {
    let prompt: Prompt
    let onFavorite: () -> Void
    
    @State private var copied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(prompt.act)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                Spacer()
                
                Button(action: {
                    onFavorite()
                }) {
                    Image(systemName: prompt.isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(prompt.isFavorite ? .red : .gray)
                }
                .buttonStyle(.plain)
                
                Button(action: {
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
                if prompt.forDevs {
                    BadgeView(icon: "laptopcomputer", text: "For Developers")
                }
                
                Spacer()
                
                Text("\(prompt.prompt.count) characters")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
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
