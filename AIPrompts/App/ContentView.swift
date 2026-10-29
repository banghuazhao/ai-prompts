import SharingGRDB
import SwiftUI

struct ContentView: View {
    @State private var selectedTab = ScreenshotLaunchConfiguration.initialTab
    @FetchAll(PromptCategory.all) private var categories
    @State private var router = DeepLinkRouter.shared
    @AppStorage("selectedThemeColor") private var selectedThemeColor = ThemeColor.default.rawValue
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                glassTabView
            } else {
                legacyTabView
            }
        }
        .tint((ThemeColor(rawValue: selectedThemeColor) ?? .default).primaryColor)
        .onAppear {
            appearance.apply()
        }
        .onChange(of: appearance) { _, newValue in
            newValue.apply()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Catches windows that weren't attached yet on first appearance.
            if newPhase == .active {
                appearance.apply()
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
        // Above the tab bar, so it stays put when a detail page that deleted its prompt closes.
        .overlay(alignment: .bottom) {
            UndoBanner()
                .padding(.bottom, 72)
        }
        // Last, so the router's sheet sees it too.
        .environment(\.promptCategories, categoriesByID)
    }

    private var categoriesByID: [PromptCategory.ID: PromptCategory] {
        Dictionary(categories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Floating Liquid Glass tab bar with a dedicated search tab that collapses while scrolling.
    @available(iOS 26.0, *)
    private var glassTabView: some View {
        TabView(selection: $selectedTab) {
            Tab("Prompts", systemImage: "text.bubble", value: 0) {
                PromptListView()
                    .readableContentWidth()
            }

            Tab("Vibe Prompts", systemImage: "laptopcomputer", value: 1) {
                VibePromptListView()
                    .readableContentWidth()
            }

            Tab("Favorites", systemImage: "heart.fill", value: 2) {
                FavoritesView()
            }

            Tab("More", systemImage: "ellipsis.circle", value: 3) {
                MoreView()
                    .readableContentWidth(.scrollView)
            }

            Tab(value: 4, role: .search) {
                SearchView()
                    .readableContentWidth()
            }
        }
        .platformTabStyle()
        .onChange(of: selectedTab) { _, _ in
            Haptics.shared.vibrateIfEnabled()
        }
    }

    private var legacyTabView: some View {
        TabView(selection: $selectedTab) {
            PromptListView()
                .readableContentWidth()
                .tabItem {
                    Label("Prompts", systemImage: "text.bubble")
                }
                .tag(0)

            VibePromptListView()
                .readableContentWidth()
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
                .readableContentWidth(.scrollView)
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
    let _ = prepareDependencies {
        $0.defaultDatabase = try! appDatabase()
    }
    ContentView()
}
