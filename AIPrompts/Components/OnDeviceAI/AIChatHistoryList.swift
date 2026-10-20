//
// Created by Banghua Zhao on 04/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import Dependencies
import SharingGRDB
import SwiftUI

/// Saved on-device conversations, newest first. Shown inside a `NavigationStack`.
struct AIChatHistoryList: View {
    let chats: [AIChat]

    @State private var searchText = ""
    @State private var renamingChat: AIChat?
    @Dependency(\.defaultDatabase) private var database

    private var filteredChats: [AIChat] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return chats }
        return chats.filter { $0.matches(query) }
    }

    var body: some View {
        if chats.isEmpty {
            EmptyFavoritesView(
                title: "No Chats Yet",
                message: "Open any prompt and tap Run on Device. Your conversations are saved here and never leave your iPhone.",
                systemImage: "sparkles"
            )
        } else {
            // Captured here, since the alert clears `renamingChat` as it dismisses.
            let chatToRename = renamingChat
            List {
                ForEach(filteredChats) { chat in
                    NavigationLink {
                        AIChatDestination(chat: chat)
                    } label: {
                        AIChatRow(chat: chat)
                    }
                    .contextMenu {
                        Button("Rename", systemImage: "pencil") {
                            renamingChat = chat
                        }
                        ShareLink(item: AIMessage.transcript(chat.messages)) {
                            Label("Share Conversation", systemImage: "square.and.arrow.up")
                        }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            delete([chat.id])
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button("Rename", systemImage: "pencil") {
                            Haptics.shared.vibrateIfEnabled()
                            renamingChat = chat
                        }
                        .tint(AIStudioPalette.violet)
                    }
                }
                .onDelete { offsets in
                    let chats = filteredChats
                    delete(offsets.map { chats[$0].id })
                }
            }
            .listStyle(PlainListStyle())
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search chats")
            .overlay {
                if filteredChats.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .renameChatAlert(
                isPresented: Binding(
                    get: { renamingChat != nil },
                    set: { if !$0 { renamingChat = nil } }
                ),
                title: chatToRename?.title ?? ""
            ) { newTitle in
                if let chatToRename {
                    AIChat.rename(id: chatToRename.id, to: newTitle, database: database)
                }
            }
        }
    }

    private func delete(_ ids: [AIChat.ID]) {
        withErrorReporting {
            try database.write { db in
                try AIChat.where { $0.id.in(ids) }.delete().execute(db)
            }
        }
    }
}

private struct AIChatRow: View {
    let chat: AIChat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(chat.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(chat.modifiedDate, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(chat.preview)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }
}

/// Continues the chat when the on-device model is available, otherwise shows it read-only.
private struct AIChatDestination: View {
    let chat: AIChat

    var body: some View {
        if #available(iOS 26.0, *), OnDeviceAI.status == .available {
            OnDeviceChatScreen(chat: chat)
        } else {
            AIChatDetailView(chat: chat)
        }
    }
}

private struct AIChatDetailView: View {
    let chat: AIChat

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(chat.messages) { message in
                    AIMessageView(message: message, title: chat.title)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: AIMessage.transcript(chat.messages)) {
                    Image(systemName: "square.and.arrow.up")
                }
                .simultaneousGesture(TapGesture().onEnded { PromptActions.share() })
            }
        }
    }
}

extension View {
    /// An alert with a text field for renaming a saved chat. `onRename` gets the new title.
    func renameChatAlert(
        isPresented: Binding<Bool>,
        title: String,
        onRename: @escaping (String) -> Void
    ) -> some View {
        modifier(RenameChatAlert(isPresented: isPresented, currentTitle: title, onRename: onRename))
    }
}

private struct RenameChatAlert: ViewModifier {
    @Binding var isPresented: Bool
    let currentTitle: String
    let onRename: (String) -> Void

    @State private var newTitle = ""

    func body(content: Content) -> some View {
        content
            .alert("Rename Chat", isPresented: $isPresented) {
                TextField("Title", text: $newTitle)
                Button("Cancel", role: .cancel) {}
                Button("Rename") {
                    Haptics.shared.vibrateIfEnabled()
                    onRename(newTitle)
                }
                .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .onChange(of: isPresented) { _, isPresented in
                if isPresented {
                    newTitle = currentTitle
                }
            }
    }
}
