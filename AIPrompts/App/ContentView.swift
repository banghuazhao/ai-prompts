import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var router = DeepLinkRouter.shared

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                glassTabView
            } else {
                legacyTabView
            }
        }
        .onOpenURL { url in
            router.handle(url)
        }
        .onChange(of: router.requestedTab) { _, tab in
            guard let tab else { return }
            selectedTab = tab
            router.requestedTab = nil
        }
        .sheet(item: $router.destination) { destination in
            NavigationStack {
                Group {
                    switch destination {
                    case let .prompt(prompt):
                        PromptDetailView(model: PromptDetailModel(prompt: prompt))
                    case let .vibePrompt(vibePrompt):
                        VibePromptDetailView(model: VibePromptDetailModel(vibePrompt: vibePrompt))
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            router.destination = nil
                        }
                    }
                }
            }
        }
    }

    /// Floating Liquid Glass tab bar with a dedicated search tab that collapses while scrolling.
    @available(iOS 26.0, *)
    private var glassTabView: some View {
        TabView(selection: $selectedTab) {
            Tab("Prompts", systemImage: "text.bubble", value: 0) {
                PromptListView()
            }

            Tab("Vibe Prompts", systemImage: "laptopcomputer", value: 1) {
                VibePromptListView()
            }

            Tab("Favorites", systemImage: "heart.fill", value: 2) {
                FavoritesView()
            }

            Tab("More", systemImage: "ellipsis.circle", value: 3) {
                MoreView()
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
        }
        .onChange(of: selectedTab) { _ in
            Haptics.shared.vibrateIfEnabled()
        }
    }
}

#Preview {
    ContentView()
}
