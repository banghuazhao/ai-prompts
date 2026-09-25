//
// Created by Banghua Zhao on 25/09/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI
import WidgetKit

struct DailyPromptEntry: TimelineEntry {
    let date: Date
    let item: WidgetPromptItem
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
        completion(Timeline(entries: [entry(for: now), entry(for: tomorrow)], policy: .after(tomorrow)))
    }

    private func entry(for date: Date) -> DailyPromptEntry {
        let item = WidgetShared.loadSnapshot()?.promptOfTheDay(for: date) ?? .sample
        return DailyPromptEntry(date: date, item: item)
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
                Label("Today's Prompt", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.purple)
                    .lineLimit(1)
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
        .description("A new AI prompt every day. Tap to open it.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

#Preview(as: .systemMedium) {
    PromptOfTheDayWidget()
} timeline: {
    DailyPromptEntry(date: .now, item: .sample)
}
