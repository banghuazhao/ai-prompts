//
// Created by Banghua Zhao on 27/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import Dependencies
import Observation
import OSLog
import SharingGRDB
import SwiftUI

private let logger = Logger(subsystem: "AIPrompts", category: "Undo")

/// A short message at the bottom of the screen, such as "Prompt deleted", with an optional Undo.
///
/// Shown above every tab by `ContentView`, so it stays visible after a detail page that deleted
/// its prompt closes.
@Observable
@MainActor
final class UndoCenter {
    static let shared = UndoCenter()

    struct Notice: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let canUndo: Bool
    }

    private(set) var notice: Notice?

    @ObservationIgnored private var undoAction: (() -> Void)?
    @ObservationIgnored private var hideTask: Task<Void, Never>?

    /// How long a notice with Undo stays up. Long enough to notice and reach the button.
    static let undoDuration: Duration = .seconds(6)
    static let messageDuration: Duration = .seconds(3)

    /// Shows `message`, replacing any notice already up. Its Undo, if any, can no longer be used.
    func show(_ message: String, undo: (() -> Void)? = nil) {
        undoAction = undo
        withAnimation(.spring(duration: 0.3)) {
            notice = Notice(message: message, canUndo: undo != nil)
        }
        let duration = undo == nil ? Self.messageDuration : Self.undoDuration
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    func undo() {
        let action = undoAction
        dismiss()
        action?()
    }

    func dismiss() {
        hideTask?.cancel()
        hideTask = nil
        undoAction = nil
        withAnimation(.spring(duration: 0.3)) {
            notice = nil
        }
    }
}

/// Deletes prompts right away and offers Undo, instead of asking "Are you sure?" first.
@MainActor
enum PromptTrash {
    static func delete(_ prompt: Prompt) {
        @Dependency(\.defaultDatabase) var database
        delete([prompt], in: database)
    }

    static func delete(_ prompts: [Prompt]) {
        @Dependency(\.defaultDatabase) var database
        delete(prompts, in: database)
    }

    static func delete(_ prompts: [Prompt], in database: any DatabaseWriter) {
        guard !prompts.isEmpty else { return }
        let ids = prompts.map(\.id)
        let usages: [PromptUsage]
        do {
            usages = try database.write { db -> [PromptUsage] in
                // Usage rows go with their prompt (ON DELETE CASCADE), so keep a copy to put back.
                let saved = try PromptUsage.where { $0.promptID.in(ids) }.fetchAll(db)
                try Prompt.where { $0.id.in(ids) }.delete().execute(db)
                return saved
            }
        } catch {
            logger.error("Failed to delete prompts: \(error.localizedDescription)")
            return
        }
        let message = prompts.count == 1
            ? String(localized: "Deleted “\(prompts[0].act)”")
            : String(localized: "\(prompts.count) prompts deleted")
        UndoCenter.shared.show(message) {
            restore(prompts, usages: usages, in: database)
        }
    }

    /// Puts the prompts back with their original ids, so favorites, categories, usage history
    /// and links from widgets and Spotlight all still point at them.
    private static func restore(_ prompts: [Prompt], usages: [PromptUsage], in database: any DatabaseWriter) {
        do {
            try database.write { db in
                for prompt in prompts {
                    try Prompt.upsert { Prompt.Draft(prompt) }.execute(db)
                }
                for usage in usages {
                    try db.execute(
                        sql: """
                        INSERT OR REPLACE INTO "promptUsages" ("id", "promptID", "lastUsedDate", "useCount")
                        VALUES (?, ?, ?, ?)
                        """,
                        arguments: [usage.id, usage.promptID, usage.lastUsedDate, usage.useCount]
                    )
                }
            }
        } catch {
            logger.error("Failed to restore prompts: \(error.localizedDescription)")
            UndoCenter.shared.show(String(localized: "Couldn't restore the deleted prompts."))
        }
    }

    static func delete(_ vibePrompt: VibePrompt) {
        @Dependency(\.defaultDatabase) var database
        delete([vibePrompt], in: database)
    }

    static func delete(_ vibePrompts: [VibePrompt], in database: any DatabaseWriter) {
        guard !vibePrompts.isEmpty else { return }
        let ids = vibePrompts.map(\.id)
        let usages: [VibePromptUsage]
        do {
            usages = try database.write { db -> [VibePromptUsage] in
                let saved = try VibePromptUsage.where { $0.vibePromptID.in(ids) }.fetchAll(db)
                try VibePrompt.where { $0.id.in(ids) }.delete().execute(db)
                return saved
            }
        } catch {
            logger.error("Failed to delete vibe prompts: \(error.localizedDescription)")
            return
        }
        let message = vibePrompts.count == 1
            ? String(localized: "Deleted “\(vibePrompts[0].app)”")
            : String(localized: "\(vibePrompts.count) prompts deleted")
        UndoCenter.shared.show(message) {
            restore(vibePrompts, usages: usages, in: database)
        }
    }

    private static func restore(_ vibePrompts: [VibePrompt], usages: [VibePromptUsage], in database: any DatabaseWriter) {
        do {
            try database.write { db in
                for vibePrompt in vibePrompts {
                    try VibePrompt.upsert { VibePrompt.Draft(vibePrompt) }.execute(db)
                }
                for usage in usages {
                    try db.execute(
                        sql: """
                        INSERT OR REPLACE INTO "vibePromptUsages" ("id", "vibePromptID", "lastUsedDate", "useCount")
                        VALUES (?, ?, ?, ?)
                        """,
                        arguments: [usage.id, usage.vibePromptID, usage.lastUsedDate, usage.useCount]
                    )
                }
            }
        } catch {
            logger.error("Failed to restore vibe prompts: \(error.localizedDescription)")
            UndoCenter.shared.show(String(localized: "Couldn't restore the deleted prompts."))
        }
    }
}

/// The notice from `UndoCenter`, as a floating capsule.
struct UndoBanner: View {
    @State private var center = UndoCenter.shared

    var body: some View {
        if let notice = center.notice {
            HStack(spacing: 12) {
                Text(notice.message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if notice.canUndo {
                    Button("Undo") {
                        Haptics.shared.vibrateIfEnabled()
                        center.undo()
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(AIStudioPalette.cyan)
                    .frame(minHeight: 44)
                }
            }
            .padding(.leading, 18)
            .padding(.trailing, notice.canUndo ? 10 : 18)
            .frame(minHeight: 50)
            .background(AIStudioPalette.ink.opacity(0.92), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.14)))
            .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
            .padding(.horizontal, 16)
            .id(notice.id)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isStaticText)
            .onAppear {
                UIAccessibility.post(notification: .announcement, argument: notice.message)
            }
        }
    }
}
