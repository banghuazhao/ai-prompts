import Foundation
import SharingGRDB

@Table
struct VibePrompt: Identifiable, Hashable {
    let id: Int
    var app: String = ""
    var prompt: String = ""
    var contributor: String = ""
    var techstack: String = ""
    var isFavorite: Bool = false
    var modifiedDate: Date = Date()
    /// Set when the prompt arrived through a content update (bundled or remote feed).
    var addedDate: Date? = nil

    var isNew: Bool {
        guard let addedDate else { return false }
        return Date().timeIntervalSince(addedDate) < ContentKey.newContentWindow
    }

    var techstackArray: [String] {
        techstack.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    var contributorGithubURL: URL {
        let username = contributor.first == "@" ? String(contributor.dropFirst()) : contributor
        let value = "https://github.com/" + username
        return URL(string: value) ?? URL(string: "https://github.com/banghuazhao/ai-prompts")!
    }
}

extension VibePrompt.Draft: Identifiable, Hashable {}
