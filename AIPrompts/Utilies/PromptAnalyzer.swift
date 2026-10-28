import Foundation
import NaturalLanguage

struct PromptIssue: Identifiable {
    enum Kind: Equatable {
        case tooShort
        case tooLong
        case vagueWords
        case fillerWords
        case leadingLanguage
        case repeatedSentences
        case noOutputFormat
        case noAudience
        case noExamples
        case noStructure
        case processWithoutSteps
    }

    let id = UUID()
    let kind: Kind
    let type: String
    let description: String
    let suggestion: String?
}

/// Quick, rule-based tips for a prompt, shown by Check Prompt and passed to Improve with
/// Apple Intelligence as hints.
///
/// Size and repetition checks work in any language. Checks that look for English words only run
/// on English prompts, and they match whole words, so "whole" doesn't count as "who".
enum PromptAnalyzer {
    static let vagueWords = ["thing", "things", "stuff", "something", "anything", "everything"]
    static let fillerWords = ["just", "basically", "kind of", "sort of", "actually", "really", "very"]
    static let leadingWords = ["obviously", "clearly", "everyone knows", "of course"]
    static let formatWords = [
        "json", "table", "list", "bullet", "bullets", "markdown", "csv", "yaml", "paragraph", "paragraphs",
        "essay", "poem", "story", "outline", "summary", "headings", "format", "sentences", "words", "code",
        "email", "letter", "script", "steps",
    ]
    static let audienceWords = [
        "audience", "beginner", "beginners", "expert", "experts", "child", "children", "kid", "kids",
        "student", "students", "professional", "professionals", "reader", "readers", "customer", "customers",
        "client", "clients", "user", "users", "team", "non-technical", "year-old", "year old",
    ]
    static let exampleWords = ["for example", "e.g.", "such as", "for instance", "example", "examples", "like this"]
    static let stepWords = ["step", "steps", "first", "then", "next", "finally", "after that"]

    /// Below this many words a prompt is likely too vague to get a useful answer.
    static let minWords = 5
    static let maxWords = 300
    /// Checks for missing details (format, audience…) only apply from this many words up,
    /// so short, simple requests aren't nagged.
    static let detailedPromptWords = 40

    static func analyze(_ prompt: String) -> [PromptIssue] {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }

        let wordCount = countWords(in: text)
        var issues: [PromptIssue] = []

        if wordCount < minWords {
            issues.append(PromptIssue(
                kind: .tooShort,
                type: String(localized: "Clarity"),
                description: String(localized: "Prompt is very short and may be too generic."),
                suggestion: String(localized: "Add a bit more detail to clarify your request.")
            ))
        }
        if wordCount > maxWords {
            issues.append(PromptIssue(
                kind: .tooLong,
                type: String(localized: "Conciseness"),
                description: String(localized: "Prompt is very long. Consider shortening if possible."),
                suggestion: String(localized: "Remove unnecessary words for clarity.")
            ))
        }
        if hasRepeatedSentences(text) {
            issues.append(PromptIssue(
                kind: .repeatedSentences,
                type: String(localized: "Redundancy"),
                description: String(localized: "Prompt contains repeated sentences or phrases."),
                suggestion: String(localized: "Remove repeated instructions to keep your prompt focused.")
            ))
        }

        guard isEnglish(text) else { return issues }

        if count(vagueWords, in: text) >= 2 {
            issues.append(PromptIssue(
                kind: .vagueWords,
                type: String(localized: "Clarity"),
                description: String(localized: "Prompt contains several vague words (e.g., 'things', 'something')."),
                suggestion: String(localized: "Try to be a bit more specific about what you want.")
            ))
        }
        if count(fillerWords, in: text) >= 2 {
            issues.append(PromptIssue(
                kind: .fillerWords,
                type: String(localized: "Conciseness"),
                description: String(localized: "Prompt contains several filler words (e.g., 'just', 'basically')."),
                suggestion: String(localized: "Remove filler words for clarity.")
            ))
        }
        if count(leadingWords, in: text) >= 2 {
            issues.append(PromptIssue(
                kind: .leadingLanguage,
                type: String(localized: "Neutrality"),
                description: String(localized: "Prompt contains several leading or biased phrases."),
                suggestion: String(localized: "Use neutral language to avoid biasing the AI's response.")
            ))
        }

        guard wordCount >= detailedPromptWords else { return issues }

        if count(formatWords, in: text) == 0 {
            issues.append(PromptIssue(
                kind: .noOutputFormat,
                type: String(localized: "Format/Output"),
                description: String(localized: "For longer prompts, consider specifying the desired output format."),
                suggestion: String(localized: "E.g., 'Respond in JSON'.")
            ))
        }
        if wordCount >= 60, count(audienceWords, in: text) == 0 {
            issues.append(PromptIssue(
                kind: .noAudience,
                type: String(localized: "Audience"),
                description: String(localized: "For longer prompts, consider specifying the intended audience."),
                suggestion: String(localized: "E.g., 'Explain for a beginner'.")
            ))
        }
        if wordCount >= 80, count(exampleWords, in: text) == 0 {
            issues.append(PromptIssue(
                kind: .noExamples,
                type: String(localized: "Examples"),
                description: String(localized: "For longer prompts, consider providing an example."),
                suggestion: String(localized: "Add an example to clarify your request.")
            ))
        }
        let hasSteps = count(stepWords, in: text) > 0
        if wordCount >= 120, !hasSteps, !hasListMarkers(text) {
            issues.append(PromptIssue(
                kind: .noStructure,
                type: String(localized: "Structure"),
                description: String(localized: "Long prompt could benefit from more structure (steps, lists, etc.)."),
                suggestion: String(localized: "Break your instructions into steps or a list if possible.")
            ))
        }
        if count(["process"], in: text) > 0, !hasSteps {
            issues.append(PromptIssue(
                kind: .processWithoutSteps,
                type: String(localized: "Completeness"),
                description: String(localized: "Prompt asks for a process but does not specify steps."),
                suggestion: String(localized: "List the steps or details needed for the process.")
            ))
        }
        return issues
    }

    // MARK: - Helpers

    /// Word count from the system's word boundaries, so it also works for languages without spaces.
    static func countWords(in text: String) -> Int {
        var count = 0
        text.enumerateSubstrings(in: text.startIndex..., options: [.byWords, .substringNotRequired]) { _, _, _, _ in
            count += 1
        }
        return count
    }

    static func isEnglish(_ text: String) -> Bool {
        NLLanguageRecognizer.dominantLanguage(for: text) == .english
    }

    /// How many of `phrases` appear in `text` as whole words, ignoring case.
    static func count(_ phrases: [String], in text: String) -> Int {
        phrases.filter { containsWholePhrase($0, in: text) }.count
    }

    static func containsWholePhrase(_ phrase: String, in text: String) -> Bool {
        // Not preceded or followed by a letter or digit, so "e.g." and "year-old" work too.
        let pattern = #"(?<![\p{L}\p{N}])"# + NSRegularExpression.escapedPattern(for: phrase) + #"(?![\p{L}\p{N}])"#
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// Lines that start like a list: "- ", "* ", "• " or "1. " / "1) ".
    static func hasListMarkers(_ text: String) -> Bool {
        text.range(of: #"(?m)^\s*(?:[-*•]|\d+[.)])\s+"#, options: .regularExpression) != nil
    }

    /// The same sentence more than once. Very short sentences like "Thanks." don't count.
    static func hasRepeatedSentences(_ text: String) -> Bool {
        var seen = Set<String>()
        var repeated = false
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { sentence, _, _, stop in
            guard let sentence else { return }
            let normalized = sentence
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            guard countWords(in: normalized) >= 4 else { return }
            if !seen.insert(normalized).inserted {
                repeated = true
                stop = true
            }
        }
        return repeated
    }
}
