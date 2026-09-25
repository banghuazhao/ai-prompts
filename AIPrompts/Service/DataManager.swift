import Foundation
import SwiftUI

class DataManager: ObservableObject {
    static let shared = DataManager()

    func loadPromptsDraft() -> [Prompt.Draft] {
        CSVParser.parseResource(named: "prompts").compactMap { columns in
            guard columns.count >= 3 else { return nil }

            let act = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let prompt = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let forDevs = columns[2].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "true"

            return Prompt.Draft(act: act, prompt: prompt, forDevs: forDevs)
        }
    }

    func loadVibePromptsDraft() -> [VibePrompt.Draft] {
        CSVParser.parseResource(named: "vibeprompts").compactMap { columns in
            guard columns.count >= 4 else { return nil }

            let app = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let prompt = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let contributor = columns[2].trimmingCharacters(in: .whitespacesAndNewlines)
            let techstack = columns[3].trimmingCharacters(in: .whitespacesAndNewlines)

            return VibePrompt.Draft(app: app, prompt: prompt, contributor: contributor, techstack: techstack)
        }
    }
}
