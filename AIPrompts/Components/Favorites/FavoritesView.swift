import SharingGRDB
import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedTab = 0

    @FetchAll(
        Prompt.all
            .where(\.isFavorite)
    ) var favoritePrompts

    @FetchAll(
        VibePrompt.all
            .where(\.isFavorite)
    ) var favoriteVibePrompts

    var body: some View {
        NavigationView {
            VStack {
                // Tab Picker
                Picker("Favorites", selection: $selectedTab) {
                    Text("Prompts (\(favoritePrompts.count))").tag(0)
                    Text("Vibe Prompts (\(favoriteVibePrompts.count))").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                // Content based on selected tab
                if selectedTab == 0 {
                    if favoritePrompts.isEmpty {
                        EmptyFavoritesView(
                            title: "No Favorite Prompts",
                            message: "Prompts you favorite will appear here",
                            systemImage: "heart"
                        )
                    } else {
                        List(favoritePrompts) { prompt in
                            NavigationLink(
                                destination: PromptDetailView(
                                    model: PromptDetailModel(prompt: prompt)
                                )
                            ) {
                                PromptRowView(prompt: prompt) {
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                } else {
                    if favoriteVibePrompts.isEmpty {
                        EmptyFavoritesView(
                            title: "No Favorite Vibe Prompts",
                            message: "Vibe prompts you favorite will appear here",
                            systemImage: "sparkles"
                        )
                    } else {
                        List(favoriteVibePrompts) { vibePrompt in
                            NavigationLink(
                                destination: VibePromptDetailView(
                                    model: .init(vibePrompt: vibePrompt)
                                )
                            ) {
                                VibePromptRowView(vibePrompt: vibePrompt) {
//                                    model.onDeleteRequest(vibePrompt)
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct EmptyFavoritesView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: systemImage)
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.05))
    }
}
