//
// Created by Banghua Zhao on 27/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import Foundation

// Compiled into the app, the widget extension and the share extension.

/// Text that arrived from the clipboard or the share sheet, split into a title and the prompt.
struct ImportedPrompt: Codable, Equatable {
    /// Titles are short; a longer first line is part of the prompt rather than its name.
    static let maxTitleLength = 60

    var title: String
    var prompt: String

    init(title: String, prompt: String) {
        self.title = title
        self.prompt = prompt
    }

    /// A short first line followed by more text becomes the title, without Markdown heading or
    /// bold marks. Otherwise the title is left empty for the user (or Apple Intelligence) to fill.
    /// Nil when there's no text at all.
    init?(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lines = trimmed.split(maxSplits: 1, omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        if lines.count == 2 {
            let firstLine = lines[0]
                .trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "#*_:")))
            let rest = lines[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if !firstLine.isEmpty, firstLine.count <= Self.maxTitleLength, !rest.isEmpty {
                self.init(title: firstLine, prompt: rest)
                return
            }
        }
        self.init(title: "", prompt: trimmed)
    }
}

/// Prompts saved from the share sheet, waiting in the App Group container until the app opens
/// and adds them to the library. The share extension can't open the app's database itself.
enum SharedInbox {
    private static var url: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WidgetShared.appGroupID)?
            .appendingPathComponent("shared-inbox.json")
    }

    static func load() -> [ImportedPrompt] {
        guard let url, let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([ImportedPrompt].self, from: data)) ?? []
    }

    static func append(_ prompt: ImportedPrompt) throws {
        guard let url else { throw CocoaError(.fileNoSuchFile) }
        let data = try JSONEncoder().encode(load() + [prompt])
        try data.write(to: url, options: .atomic)
    }

    /// Everything waiting, oldest first, and empties the inbox.
    static func takeAll() -> [ImportedPrompt] {
        let prompts = load()
        if !prompts.isEmpty, let url {
            try? FileManager.default.removeItem(at: url)
        }
        return prompts
    }
}
