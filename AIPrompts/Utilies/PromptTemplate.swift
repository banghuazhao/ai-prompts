import Foundation

/// Detects fill-in-the-blank variables in a prompt and renders it with user supplied values.
///
/// Supported placeholders:
/// - `{{topic}}`
/// - `${Company Type: Big Company}` (the text after `:` is the default value)
/// - A trailing example request such as `My first request is "I need a story."`,
///   which becomes a "Your first request" variable prefilled with the example.
struct PromptTemplate {
    struct Variable: Identifiable, Hashable {
        let id: String
        let label: String
        let defaultValue: String
    }

    private enum Segment {
        case text(String)
        /// `original` is rendered back when the user leaves the variable empty.
        case variable(id: String, original: String)
    }

    private struct Match {
        let range: NSRange
        let variable: Variable
    }

    private struct Rule {
        let regex: NSRegularExpression
        let extract: (NSTextCheckingResult, NSString) -> Match?
    }

    private let segments: [Segment]
    let variables: [Variable]

    var hasVariables: Bool { !variables.isEmpty }

    var defaultValues: [String: String] {
        Dictionary(uniqueKeysWithValues: variables.map { ($0.id, $0.defaultValue) })
    }

    init(_ text: String) {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        var matches: [Match] = []
        for rule in Self.rules {
            for result in rule.regex.matches(in: text, range: fullRange) {
                if let match = rule.extract(result, nsText) {
                    matches.append(match)
                }
            }
        }
        matches.sort { $0.range.location < $1.range.location }

        var segments: [Segment] = []
        var variables: [Variable] = []
        var cursor = 0
        // Overlapping matches are dropped; the earliest one wins.
        for match in matches where match.range.location >= cursor {
            if match.range.location > cursor {
                let textRange = NSRange(location: cursor, length: match.range.location - cursor)
                segments.append(.text(nsText.substring(with: textRange)))
            }
            segments.append(.variable(id: match.variable.id, original: nsText.substring(with: match.range)))
            if !variables.contains(where: { $0.id == match.variable.id }) {
                variables.append(match.variable)
            }
            cursor = NSMaxRange(match.range)
        }
        if cursor < nsText.length {
            segments.append(.text(nsText.substring(from: cursor)))
        }

        self.segments = segments
        self.variables = variables
    }

    func render(_ values: [String: String]) -> String {
        segments.map { segment -> String in
            switch segment {
            case let .text(text):
                return text
            case let .variable(id, original):
                let value = values[id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return value.isEmpty ? original : value
            }
        }
        .joined()
    }

    // MARK: - Rules

    private static let rules: [Rule] = [mustacheRule, dollarRule, firstRequestRule].compactMap { $0 }

    /// `{{topic}}`
    private static let mustacheRule: Rule? = makeRule(#"\{\{\s*([^{}]+?)\s*\}\}"#) { result, text in
        let name = text.substring(with: result.range(at: 1))
        return Match(
            range: result.range,
            variable: Variable(id: name, label: name, defaultValue: "")
        )
    }

    /// `${Name}` or `${Name: default}`
    private static let dollarRule: Rule? = makeRule(#"\$\{\s*([^{}:]+?)\s*(?::\s*([^{}]*?)\s*)?\}"#) { result, text in
        let name = text.substring(with: result.range(at: 1))
        let defaultRange = result.range(at: 2)
        let defaultValue = defaultRange.location == NSNotFound ? "" : text.substring(with: defaultRange)
        return Match(
            range: result.range,
            variable: Variable(id: name, label: name, defaultValue: defaultValue)
        )
    }

    /// `My first request is "..."` at the end of the prompt. Quotes are optional so prompts
    /// stored before the CSV parser kept quotes are still detected.
    private static let firstRequestRule: Rule? = makeRule(
        #"\b[Mm]y first ((?:[A-Za-z]+ ){0,3}?[A-Za-z]+)(?: (?:is|are|will be|would be))?\s*[:,–-]?\s*(?:["“](.*)["”]|([^\s"“].*?))\s*[.!]?\s*$"#,
        options: [.dotMatchesLineSeparators]
    ) { result, text in
        let noun = text.substring(with: result.range(at: 1))
        let quotedRange = result.range(at: 2)
        let valueRange = quotedRange.location != NSNotFound ? quotedRange : result.range(at: 3)
        guard valueRange.location != NSNotFound, valueRange.length > 0 else { return nil }

        let example = text.substring(with: valueRange)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"\u{201C}\u{201D}")))
        return Match(
            range: valueRange,
            variable: Variable(id: "first \(noun)", label: "Your first \(noun)", defaultValue: example)
        )
    }

    private static func makeRule(
        _ pattern: String,
        options: NSRegularExpression.Options = [],
        extract: @escaping (NSTextCheckingResult, NSString) -> Match?
    ) -> Rule? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            assertionFailure("Invalid PromptTemplate pattern: \(pattern)")
            return nil
        }
        return Rule(regex: regex, extract: extract)
    }
}
