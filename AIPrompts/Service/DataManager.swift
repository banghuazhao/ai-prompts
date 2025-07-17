import Foundation
import SwiftUI

class DataManager: ObservableObject {
    static let shared = DataManager()

    func loadPromptsDraft() -> [Prompt.Draft] {
        guard let url = Bundle.main.url(forResource: "prompts", withExtension: "csv") else {
            print("Could not find prompts.csv")
            return []
        }
        
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let rows = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
            
            // Skip header row
            let dataRows = Array(rows.dropFirst())
            
            return dataRows.compactMap { row in
                let columns = parseCSVRow(row)
                guard columns.count >= 3 else { return nil }
                
                let act = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let prompt = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
                let forDevs = columns[2].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "true"
                
                return Prompt.Draft(act: act, prompt: prompt, forDevs: forDevs)
            }
        } catch {
            print("Error loading prompts: \(error)")
            return []
        }
    }
    
    func loadVibePromptsDraft() -> [VibePrompt.Draft] {
        guard let url = Bundle.main.url(forResource: "vibeprompts", withExtension: "csv") else {
            print("Could not find vibeprompts.csv")
            return []
        }
        
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let rows = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
            
            // Skip header row
            let dataRows = Array(rows.dropFirst())
            
            return dataRows.compactMap { row in
                let columns = parseCSVRow(row)
                guard columns.count >= 4 else { return nil }
                
                let app = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let prompt = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
                let contributor = columns[2].trimmingCharacters(in: .whitespacesAndNewlines)
                let techstack = columns[3].trimmingCharacters(in: .whitespacesAndNewlines)
                
                return VibePrompt.Draft(app: app, prompt: prompt, contributor: contributor, techstack: techstack)
            }
        } catch {
            print("Error loading vibe prompts: \(error)")
            return []
        }
    }
    
    private func parseCSVRow(_ row: String) -> [String] {
        var columns: [String] = []
        var currentColumn = ""
        var insideQuotes = false
        
        for char in row {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                columns.append(currentColumn)
                currentColumn = ""
            } else {
                currentColumn.append(char)
            }
        }
        
        columns.append(currentColumn)
        return columns
    }
} 
