import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        TabView {
            PromptListView()
                .tabItem {
                    Label("Prompts", systemImage: "text.bubble")
                }
            
            VibePromptListView()
                .tabItem {
                    Label("Vibe Prompts", systemImage: "sparkles")
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
        .environmentObject(DataManager())
} 
