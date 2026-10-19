//
// Created by Banghua Zhao on 04/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import Foundation
import SharingGRDB

struct AIMessage: Identifiable, Hashable, Codable {
    enum Role: String, Codable {
        case user
        case assistant
    }

    var id = UUID()
    let role: Role
    var text: String
}

/// A saved conversation with the on-device model.
@Table
struct AIChat: Identifiable, Hashable {
    let id: Int
    var title: String = ""
    /// JSON encoded `[AIMessage]`.
    var messagesJSON: String = "[]"
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()

    var messages: [AIMessage] {
        AIChat.decode(messagesJSON)
    }

    /// The first reply, used as a preview in the history list.
    var preview: String {
        messages.first { $0.role == .assistant }?.text ?? ""
    }

    /// Whether the title or any message contains `query`.
    func matches(_ query: String) -> Bool {
        title.localizedStandardContains(query)
            || messages.contains { $0.text.localizedStandardContains(query) }
    }

    /// Renames a saved chat. A blank title is ignored.
    static func rename(id: AIChat.ID, to title: String, database: any DatabaseWriter) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        withErrorReporting {
            try database.write { db in
                try AIChat.find(id).update { $0.title = title }.execute(db)
            }
        }
    }

    static func encode(_ messages: [AIMessage]) -> String {
        guard let data = try? JSONEncoder().encode(messages) else { return "[]" }
        return String(decoding: data, as: UTF8.self)
    }

    static func decode(_ json: String) -> [AIMessage] {
        (try? JSONDecoder().decode([AIMessage].self, from: Data(json.utf8))) ?? []
    }
}

extension AIChat.Draft: Identifiable, Hashable {}
