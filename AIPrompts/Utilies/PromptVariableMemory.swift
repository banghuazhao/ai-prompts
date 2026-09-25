//
// Created by Banghua Zhao on 25/09/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import Foundation

/// Remembers what the user typed for blank variables such as `{{language}}` or `${Audience}`,
/// so the next prompt asking for the same thing is pre-filled.
///
/// Variables that come with their own default (e.g. the "Your first request" example)
/// always start from that default instead.
enum PromptVariableMemory {
    private static let key = "promptVariableValues"

    static func initialValues(for template: PromptTemplate) -> [String: String] {
        let remembered = load()
        var values = template.defaultValues
        for variable in template.variables where variable.defaultValue.isEmpty {
            if let value = remembered[memoryKey(variable.id)] {
                values[variable.id] = value
            }
        }
        return values
    }

    static func save(_ values: [String: String], for template: PromptTemplate) {
        var stored = load()
        for variable in template.variables where variable.defaultValue.isEmpty {
            let value = values[variable.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !value.isEmpty {
                stored[memoryKey(variable.id)] = value
            }
        }
        UserDefaults.standard.set(stored, forKey: key)
    }

    private static func load() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
    }

    private static func memoryKey(_ id: String) -> String {
        id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
