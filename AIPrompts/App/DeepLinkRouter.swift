//
// Created by Banghua Zhao on 25/09/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import Foundation
import Observation
import SharingGRDB

/// Opens a prompt from a widget tap, a Shortcut or Siri.
///
/// URLs look like `aiprompts://prompt/12` or `aiprompts://vibe/3`.
@Observable
@MainActor
final class DeepLinkRouter {
    static let shared = DeepLinkRouter()

    enum Destination: Identifiable {
        case prompt(Prompt)
        case vibePrompt(VibePrompt)

        var id: String {
            switch self {
            case let .prompt(prompt): "prompt-\(prompt.id)"
            case let .vibePrompt(vibePrompt): "vibe-\(vibePrompt.id)"
            }
        }
    }

    var destination: Destination?
    /// Tab the app should switch to, e.g. Favorites from the favorites widget.
    var requestedTab: Int?

    static let favoritesTab = 2

    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard url.scheme == WidgetShared.urlScheme else { return false }
        if url.host == "favorites" {
            AppUsage.noteDeepLinkOpened()
            requestedTab = Self.favoritesTab
            return true
        }
        guard let kind = url.host.flatMap(WidgetPromptItem.Kind.init(rawValue:)),
              let rowID = url.pathComponents.dropFirst().first.flatMap({ Int($0) })
        else { return false }
        return open(kind: kind, rowID: rowID)
    }

    /// `id` is a `WidgetPromptItem.id` / `PromptEntity.id`, e.g. "prompt-12".
    @discardableResult
    func open(id: String) -> Bool {
        let parts = id.split(separator: "-", maxSplits: 1)
        guard parts.count == 2,
              let kind = WidgetPromptItem.Kind(rawValue: String(parts[0])),
              let rowID = Int(parts[1])
        else { return false }
        return open(kind: kind, rowID: rowID)
    }

    private func open(kind: WidgetPromptItem.Kind, rowID: Int) -> Bool {
        AppUsage.noteDeepLinkOpened()
        let destination: Destination? = try? AppDatabase.shared.read { db in
            switch kind {
            case .prompt:
                try Prompt.all.where { $0.id.eq(rowID) }.fetchOne(db).map(Destination.prompt)
            case .vibe:
                try VibePrompt.all.where { $0.id.eq(rowID) }.fetchOne(db).map(Destination.vibePrompt)
            }
        }
        self.destination = destination
        return destination != nil
    }
}
