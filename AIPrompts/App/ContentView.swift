import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    var body: some View {
        TabView(selection: $selectedTab) {
            PromptListView()
                .tabItem {
                    Label("Prompts", systemImage: "text.bubble")
                }
                .tag(0)
                .onAppear {
                    AdManager.requestATTPermission(with: 3)
                }

            VibePromptListView()
                .tabItem {
                    Label("Vibe Prompts", systemImage: "laptopcomputer")
                }
                .tag(1)

            FavoritesView()
                .tabItem {
                    Label("Favorites", systemImage: "heart.fill")
                }
                .tag(2)

            MoreView()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .tag(3)
                .onAppear {
                    AdManager.requestATTPermission(with: 1)
                }
        }
        .onChange(of: selectedTab) { _ in
            Haptics.shared.vibrateIfEnabled()
        }
    }
}

#Preview {
    ContentView()
}
