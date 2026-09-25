import Foundation
import SharingGRDB

@Table
struct Prompt: Identifiable, Hashable {
    let id: Int
    var act: String = ""
    var prompt: String = ""
    var forDevs: Bool = false
    var isFavorite: Bool = false
    var modifiedDate: Date = Date()
    var categoryID: PromptCategory.ID? = nil
    /// Set when the prompt arrived through a content update (bundled or remote feed).
    var addedDate: Date? = nil

    var isNew: Bool {
        guard let addedDate else { return false }
        return Date().timeIntervalSince(addedDate) < ContentKey.newContentWindow
    }
}

extension Prompt.Draft: Identifiable, Hashable {}
