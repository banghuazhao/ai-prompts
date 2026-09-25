//
// Created by Banghua Zhao on 25/09/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI
import WidgetKit

struct FavoritesEntry: TimelineEntry {
    let date: Date
    let favorites: [WidgetPromptItem]
}

struct FavoritesProvider: TimelineProvider {
    func placeholder(in context: Context) -> FavoritesEntry {
        FavoritesEntry(date: Date(), favorites: Array(repeating: .sample, count: 3))
    }

    func getSnapshot(in context: Context, completion: @escaping (FavoritesEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FavoritesEntry>) -> Void) {
        // The app reloads this timeline whenever favorites change.
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func currentEntry() -> FavoritesEntry {
        FavoritesEntry(date: Date(), favorites: WidgetShared.loadSnapshot()?.favorites ?? [])
    }
}

struct FavoritePromptsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FavoritesEntry

    private var maxRows: Int {
        family == .systemLarge ? 6 : 3
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Favorite Prompts", systemImage: "heart.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.pink)

            if entry.favorites.isEmpty {
                Spacer(minLength: 0)
                Text("Tap ♥ on any prompt to pin it here for one-tap access.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                ForEach(entry.favorites.prefix(maxRows)) { item in
                    Link(destination: item.deepLink) {
                        HStack(spacing: 8) {
                            Image(systemName: item.kind == .vibe ? "laptopcomputer" : "text.bubble")
                                .font(.caption)
                                .foregroundStyle(.purple)
                                .frame(width: 16)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                if family == .systemLarge {
                                    Text(item.text)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "\(WidgetShared.urlScheme)://favorites"))
        .promptWidgetBackground()
    }
}

struct FavoritePromptsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetShared.Kind.favorites, provider: FavoritesProvider()) { entry in
            FavoritePromptsWidgetView(entry: entry)
        }
        .configurationDisplayName("Favorite Prompts")
        .description("Your favorite prompts, one tap away.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

#Preview(as: .systemMedium) {
    FavoritePromptsWidget()
} timeline: {
    FavoritesEntry(date: .now, favorites: [.sample, .sample])
}
