//
// Created by Banghua Zhao on 25/09/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI
import WidgetKit

struct DailyPromptEntry: TimelineEntry {
    let date: Date
    let item: WidgetPromptItem
    /// Set right after the Copy button was tapped, to show a checkmark.
    var isCopied = false
}

struct DailyPromptProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyPromptEntry {
        DailyPromptEntry(date: Date(), item: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyPromptEntry) -> Void) {
        completion(entry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyPromptEntry>) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(86400)
        var entries = [entry(for: now)]
        // Just copied: show a checkmark, then the normal widget again.
        if let copy = WidgetShared.recentCopy(at: now), copy.itemID == entries[0].item.id {
            entries = [entry(for: now, isCopied: true), entry(for: copy.until)]
        }
        entries.append(entry(for: tomorrow))
        completion(Timeline(entries: entries, policy: .after(tomorrow)))
    }

    private func entry(for date: Date, isCopied: Bool = false) -> DailyPromptEntry {
        let item = WidgetShared.loadSnapshot()?.promptOfTheDay(for: date) ?? .sample
        return DailyPromptEntry(date: date, item: item, isCopied: isCopied)
    }
}

struct PromptOfTheDayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DailyPromptEntry

    var body: some View {
        content
            .widgetURL(entry.item.deepLink)
            .promptWidgetBackground()
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Label(entry.item.title, systemImage: "sparkles")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text("Prompt of the Day")
                    .font(.caption2.weight(.semibold))
                    .widgetAccentable()
                Text(entry.item.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(entry.item.text)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 6) {
                    Label("Today's Prompt", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.purple)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    WidgetCopyButton(itemID: entry.item.id, isCopied: entry.isCopied)
                }
                Text(entry.item.title)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(entry.item.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(family == .systemSmall ? 3 : 4)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct PromptOfTheDayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetShared.Kind.promptOfTheDay, provider: DailyPromptProvider()) { entry in
            PromptOfTheDayWidgetView(entry: entry)
        }
        .configurationDisplayName("Prompt of the Day")
        .description("A new AI prompt every day. Tap to open it, or copy it right from the widget.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

#Preview(as: .systemMedium) {
    PromptOfTheDayWidget()
} timeline: {
    DailyPromptEntry(date: .now, item: .sample)
}
