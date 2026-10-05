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

    @Dependency(\.defaultDatabase) private var database

    var body: some View {
        if chats.isEmpty {
            EmptyFavoritesView(
                title: "No Chats Yet",
                message: "Open any prompt and tap Run on Device. Your conversations are saved here and never leave your iPhone.",
                systemImage: "sparkles"
            )
        } else {
            List {
                ForEach(chats) { chat in
                    NavigationLink {
                        AIChatDetailView(chat: chat)
                    } label: {
                        AIChatRow(chat: chat)
                    }
                }
                .onDelete(perform: delete)
            }
            .listStyle(PlainListStyle())
        }
    }

    private func delete(at offsets: IndexSet) {
        let ids = offsets.map { chats[$0].id }
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
