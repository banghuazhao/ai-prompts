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
} 
