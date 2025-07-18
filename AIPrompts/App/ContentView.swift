import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            PromptListView()
                .tabItem {
                    Label("Prompts", systemImage: "text.bubble")
                }
                .onAppear {
                    AdManager.requestATTPermission(with: 3)
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
                .onAppear {
                    AdManager.requestATTPermission(with: 1)
                }
        }
    }
}

#Preview {
    ContentView()
}
