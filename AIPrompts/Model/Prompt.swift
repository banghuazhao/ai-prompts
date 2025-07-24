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
}

extension Prompt.Draft: Identifiable, Hashable {}
