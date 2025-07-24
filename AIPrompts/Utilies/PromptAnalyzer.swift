import Foundation

struct PromptIssue: Identifiable {
    let id = UUID()
    let type: String
    let description: String
    let suggestion: String?
}

class PromptAnalyzer {
    static let vagueWords = ["thing", "things", "stuff", "it", "something", "anything", "everything", "this", "that"]
    static let fillerWords = ["just", "basically", "kind of", "sort of", "actually", "really", "very"]
    static let leadingWords = ["obviously", "clearly", "everyone knows", "of course"]
    static let formatKeywords = ["in JSON", "as a list", "in table form", "as a table", "as a poem", "as a story"]
    static let audienceKeywords = ["for beginners", "for experts", "for children", "for a 5-year-old", "for business professionals"]
    static let exampleKeywords = ["e.g.", "for example", "such as", "like this:"]
    static let stepKeywords = ["step 1", "first", "then", "next", "finally", "after that"]

    static func analyze(_ prompt: String) -> [PromptIssue] {
        var issues: [PromptIssue] = []
        let lower = prompt.lowercased()

        // 1. Clarity (only flag if 2+ vague words)
        let vagueCount = vagueWords.filter { lower.contains($0) }.count
        if vagueCount >= 2 {
            issues.append(PromptIssue(
                type: "Clarity",
                description: "Prompt contains several vague words (e.g., 'things', 'something').",
                suggestion: "Try to be a bit more specific about what you want."
            ))
        }
        // Only flag generic verbs if prompt is very short and only uses them
        if lower.range(of: #"\b(do|make|fix|get|improve|help)\b"#, options: .regularExpression) != nil && prompt.count < 30 {
            issues.append(PromptIssue(
                type: "Clarity",
                description: "Prompt is very short and may be too generic.",
                suggestion: "Add a bit more detail to clarify your request."
            ))
        }

        // Heuristic for missing details (only for long prompts)
        if (!lower.contains("who") && !lower.contains("what") && !lower.contains("how") && !lower.contains("when") && !lower.contains("where")) && prompt.count > 120 {
            issues.append(PromptIssue(
                type: "Specificity",
                description: "For longer prompts, consider adding more details (who, what, how, when, where).",
                suggestion: "Add a bit more context if needed."
            ))
        }

        // 3. Structure (only for very long prompts)
        if !lower.contains("- ") && !lower.contains("1.") && !lower.contains("step") && !lower.contains("list") && !lower.contains("json") {
            if prompt.count > 200 {
                issues.append(PromptIssue(
                    type: "Structure",
                    description: "Long prompt could benefit from more structure (steps, lists, etc.).",
                    suggestion: "Break your instructions into steps or a list if possible."
                ))
            }
        }

        // 4. Stepwise Instructions (only for very long prompts)
        var hasStep = false
        for word in stepKeywords {
            if lower.contains(word) { hasStep = true; break }
        }
        if !hasStep && prompt.count > 200 {
            issues.append(PromptIssue(
                type: "Stepwise Instructions",
                description: "Long prompt could be easier to follow if broken into steps.",
                suggestion: "Consider breaking complex tasks into steps."
            ))
        }

        // 5. Conciseness (flag only if very long)
        if prompt.split(separator: " ").count > 200 {
            issues.append(PromptIssue(
                type: "Conciseness",
                description: "Prompt is very long. Consider shortening if possible.",
                suggestion: "Remove unnecessary words for clarity."
            ))
        }
        // Filler words: only flag if 2+ present
        let fillerCount = fillerWords.filter { lower.contains($0) }.count
        if fillerCount >= 2 {
            issues.append(PromptIssue(
                type: "Conciseness",
                description: "Prompt contains several filler words (e.g., 'just', 'basically').",
                suggestion: "Remove filler words for clarity."
            ))
        }

        // 6. Redundancy (only for long prompts)
        let sentences = prompt.split(separator: ".")
        let uniqueSentences = Set(sentences.map { $0.trimmingCharacters(in: .whitespaces) })
        if uniqueSentences.count < sentences.count && prompt.count > 120 {
            issues.append(PromptIssue(
                type: "Redundancy",
                description: "Prompt contains repeated sentences or phrases.",
                suggestion: "Remove repeated instructions to keep your prompt focused."
            ))
        }

        // 7. Format/Output Specification (only for long prompts)
        var hasFormat = false
        for word in formatKeywords {
            if lower.contains(word) { hasFormat = true; break }
        }
        if !hasFormat && prompt.count > 120 {
            issues.append(PromptIssue(
                type: "Format/Output",
                description: "For longer prompts, consider specifying the desired output format.",
                suggestion: "E.g., 'Respond in JSON'."
            ))
        }

        // 8. Audience Awareness (only for long prompts)
        var hasAudience = false
        for word in audienceKeywords {
            if lower.contains(word) { hasAudience = true; break }
        }
        if !hasAudience && prompt.count > 120 {
            issues.append(PromptIssue(
                type: "Audience",
                description: "For longer prompts, consider specifying the intended audience.",
                suggestion: "E.g., 'Explain for a beginner'."
            ))
        }

        // 9. Task Completeness (heuristic, only for long prompts)
        if lower.contains("process") && !lower.contains("step") && prompt.count > 120 {
            issues.append(PromptIssue(
                type: "Completeness",
                description: "Prompt asks for a process but does not specify steps.",
                suggestion: "List the steps or details needed for the process."
            ))
        }

        // 10. Avoiding Leading/Loaded Language (only if 2+ present)
        let leadingCount = leadingWords.filter { lower.contains($0) }.count
        if leadingCount >= 2 {
            issues.append(PromptIssue(
                type: "Neutrality",
                description: "Prompt contains several leading or biased phrases.",
                suggestion: "Use neutral language to avoid biasing the AI's response."
            ))
        }

        // 11. Use of Examples (only for long prompts)
        var hasExample = false
        for word in exampleKeywords {
            if lower.contains(word) { hasExample = true; break }
        }
        if !hasExample && prompt.count > 120 {
            issues.append(PromptIssue(
                type: "Examples",
                description: "For longer prompts, consider providing an example.",
                suggestion: "Add an example to clarify your request."
            ))
        }

        // 12. Instruction/Question Type (soften: only flag if prompt is not a question or command and is very short)
        if !prompt.hasSuffix("?") && !lower.starts(with: "please ") && !lower.starts(with: "write ") && !lower.starts(with: "generate ") && !lower.starts(with: "create ") && prompt.count < 30 {
            issues.append(PromptIssue(
                type: "Instruction Type",
                description: "Prompt is very short and may not be a clear instruction or question.",
                suggestion: "Make your prompt a clear instruction or question."
            ))
        }

        return issues
    }
} 
