import SharingGRDB
import SwiftUI
import SwiftUINavigation

@Observable
@MainActor
class FavoritesViewModel {
    var selectedTab = 0

    @ObservationIgnored
    @FetchAll(
        Prompt.all
            .where(\.isFavorite)
            .order { $0.modifiedDate.desc() }
        , animation: .default) var favoritePrompts

    @ObservationIgnored
    @FetchAll(
        VibePrompt.all
            .where(\.isFavorite)
            .order { $0.modifiedDate.desc() }
        , animation: .default) var favoriteVibePrompts

    @ObservationIgnored
    @FetchAll(AIChat.all.order { $0.modifiedDate.desc() }, animation: .default) var aiChats

    /// Saved on-device chats live here, next to favorites, so they don't need a tab of their own.
    var showsAIChats: Bool {
        OnDeviceAI.isSupported || !aiChats.isEmpty
    }

    @ObservationIgnored
    @Dependency(\.defaultDatabase) var database
    
    @ObservationIgnored
    @Dependency(\.purchaseManager) var purchaseManager

    @CasePathable
    enum Route {
        case editingPrompt(Prompt)
        case editingVibePrompt(VibePrompt)
        case showingDeletePromptAlert(Prompt)
        case showingDeleteVibePromptAlert(VibePrompt)
    }

    var route: Route?

    // Prompt actions
    func onEdit(_ prompt: Prompt) {
        route = .editingPrompt(prompt)
    }

    func onDeleteRequest(_ prompt: Prompt) {
        route = .showingDeletePromptAlert(prompt)
    }

    func confirmDelete(_ prompt: Prompt) {
        withErrorReporting {
            try database.write { db in
                try Prompt.delete(prompt).execute(db)
            }
        }
    }

    func onUpdate(_ newPrompt: Prompt) {
        withErrorReporting {
            try database.write { db in
                try Prompt.update(newPrompt).execute(db)
            }
        }
    }

    func onFavorite(_ prompt: Prompt) {
        withErrorReporting {
            var updatedPrompt = prompt
            updatedPrompt.isFavorite.toggle()
            try database.write { db in
                try Prompt.update(updatedPrompt).execute(db)
            }
        }
    }

    // VibePrompt actions
    func onEdit(_ vibePrompt: VibePrompt) {
        route = .editingVibePrompt(vibePrompt)
    }

    func onDeleteRequest(_ vibePrompt: VibePrompt) {
        route = .showingDeleteVibePromptAlert(vibePrompt)
    }

    func confirmDelete(_ vibePrompt: VibePrompt) {
        withErrorReporting {
            try database.write { db in
                try VibePrompt.delete(vibePrompt).execute(db)
            }
        }
    }

    func onUpdate(_ newVibePrompt: VibePrompt) {
        withErrorReporting {
            try database.write { db in
                try VibePrompt.update(newVibePrompt).execute(db)
            }
        }
    }

    func onFavorite(_ vibePrompt: VibePrompt) {
        withErrorReporting {
            var updatedPrompt = vibePrompt
            updatedPrompt.isFavorite.toggle()
            try database.write { db in
                try VibePrompt.update(updatedPrompt).execute(db)
            }
        }
    }
}

struct FavoritesView: View {
    @State private var model = FavoritesViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                collectionHeader

                Picker("Favorites", selection: $model.selectedTab) {
                    Text("Prompts").tag(0)
                    Text("Vibe").accessibilityLabel("Vibe Prompts").tag(1)
                    if model.showsAIChats {
                        Text("Chats").tag(2)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .accessibilityLabel("Saved item type")

                // Content based on selected tab
                if model.selectedTab == 0 {
                    if model.favoritePrompts.isEmpty {
                        EmptyFavoritesView(
                            title: "No Favorite Prompts",
                            message: "Tap the heart on a prompt to keep it close at hand.",
                            systemImage: "heart"
                        )
                    } else {
                        List(model.favoritePrompts) { prompt in
                            NavigationLink(
                                destination: PromptDetailView(
                                    model: PromptDetailModel(prompt: prompt)
                                )
                            ) {
                                PromptRowView(prompt: prompt) {
                                    model.onFavorite(prompt)
                                }
                                .contextMenu {
                                    Button(action: { model.onEdit(prompt) }) {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(action: { model.onFavorite(prompt) }) {
                                        Label(prompt.isFavorite ? "Unfavorite" : "Favorite", systemImage: prompt.isFavorite ? "heart.slash" : "heart")
                                    }
                                    Button(role: .destructive, action: { model.onDeleteRequest(prompt) }) {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                } else if model.selectedTab == 2 {
                    AIChatHistoryList(chats: model.aiChats)
                } else {
                    if model.favoriteVibePrompts.isEmpty {
                        EmptyFavoritesView(
                            title: "No Favorite Vibe Prompts",
                            message: "Tap the heart on a vibe prompt to save your ideas here.",
                            systemImage: "sparkles"
                        )
                    } else {
                        List(model.favoriteVibePrompts) { vibePrompt in
                            NavigationLink(
                                destination: VibePromptDetailView(
                                    model: .init(vibePrompt: vibePrompt)
                                )
                            ) {
                                VibePromptRowView(vibePrompt: vibePrompt) {
                                    model.onFavorite(vibePrompt)
                                }
                                .contextMenu {
                                    Button(action: { model.onEdit(vibePrompt) }) {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(action: { model.onFavorite(vibePrompt) }) {
                                        Label(vibePrompt.isFavorite ? "Unfavorite" : "Favorite", systemImage: vibePrompt.isFavorite ? "heart.slash" : "heart")
                                    }
                                    Button(role: .destructive, action: { model.onDeleteRequest(vibePrompt) }) {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
                if !model.purchaseManager.isPremiumUserPurchased {
                    BannerView()
                        .frame(height: 50)
                        .padding(.bottom, 16)
                }
            }
            .background(AIStudioPalette.canvas.ignoresSafeArea())
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.inline)
            // Prompt sheets/alerts
            .sheet(item: $model.route.editingPrompt, id: \.self) { prompt in
                PromptFormView(
                    model: PromptFormModel(prompt: Prompt.Draft(prompt)) { _ in
                        model.route = nil
                    }
                )
            }
            .sheet(item: $model.route.editingVibePrompt, id: \.self) { vibePrompt in
                VibePromptFormView(
                    model: VibePromptFormModel(prompt: VibePrompt.Draft(vibePrompt)) { _ in
                        model.route = nil
                    }
                )
            }
            .alert(
                item: $model.route.showingDeletePromptAlert,
                title: { _ in Text("Delete Prompt") },
                actions: { prompt in
                    Button("Delete", role: .destructive) {
                        model.confirmDelete(prompt)
                    }
                    Button("Cancel", role: .cancel) {}
                },
                message: { prompt in
                    Text("Are you sure you want to delete \(prompt.act)? This action cannot be undone.")
                }
            )
            .alert(
                item: $model.route.showingDeleteVibePromptAlert,
                title: { _ in Text("Delete Vibe Prompt") },
                actions: { vibePrompt in
                    Button("Delete", role: .destructive) {
                        model.confirmDelete(vibePrompt)
                    }
                    Button("Cancel", role: .cancel) {}
                },
                message: { vibePrompt in
                    Text("Are you sure you want to delete \(vibePrompt.app)? This action cannot be undone.")
                }
            )
        }
    }

    private var collectionHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: "heart.text.square.fill")
                .font(.title2)
                .foregroundStyle(AIStudioPalette.violet)
                .frame(width: 50, height: 50)
                .background(AIStudioPalette.violet.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("Your collection")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                Text("\(model.favoritePrompts.count + model.favoriteVibePrompts.count + model.aiChats.count) saved items")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(AIStudioPalette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(AIStudioPalette.border, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
}

struct EmptyFavoritesView: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 19))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text("YOUR IDEAS, READY WHEN YOU ARE")
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(AIStudioPalette.cyan)
                Text(title)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.94))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AIStudioPalette.heroGradient, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .combine)
    }
}
