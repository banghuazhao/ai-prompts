import SwiftUI

struct ContentView: View {    
    var body: some View {
        TabView {
            PromptListView()
                .tabItem {
                    Label("Prompts", systemImage: "text.bubble")
                }
            
            VibePromptListView()
                .tabItem {
                    Label("Vibe Prompts", systemImage: "laptopcomputer")
                }
            
            FavoritesView()
                .tabItem {
                    Label("Favorites", systemImage: "heart.fill")
                }
            
            MoreView()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle")
                }
        }
    }
}

#Preview {
    ContentView()
} 
