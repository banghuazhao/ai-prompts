import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        if #available(iOS 26.0, *) {
            glassTabView
        } else {
            legacyTabView
        }
    }

    /// Floating Liquid Glass tab bar with a dedicated search tab that collapses while scrolling.
    @available(iOS 26.0, *)
    private var glassTabView: some View {
        TabView(selection: $selectedTab) {
            Tab("Prompts", systemImage: "text.bubble", value: 0) {
                PromptListView()
                    .onAppear {
                        AdManager.requestATTPermission(with: 3)
                    }
            }

            Tab("Vibe Prompts", systemImage: "laptopcomputer", value: 1) {
                VibePromptListView()
            }

            Tab("Favorites", systemImage: "heart.fill", value: 2) {
                FavoritesView()
            }

            Tab("More", systemImage: "ellipsis.circle", value: 3) {
                MoreView()
                    .onAppear {
                        AdManager.requestATTPermission(with: 1)
                    }
            }

            Tab(value: 4, role: .search) {
                SearchView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .onChange(of: selectedTab) { _, _ in
            Haptics.shared.vibrateIfEnabled()
        }
    }

    private var legacyTabView: some View {
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
