//
// Created by Banghua Zhao on 23/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import Foundation

/// The block structure of a Markdown reply: headings, lists, code, quotes and paragraphs.
/// Inline styling (bold, links, `code`) is left in the text for `AttributedString` to handle.
///
/// Built for streamed replies: it never fails, and an unclosed code fence runs to the end.
enum MarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    /// `start` is the first number for an ordered list, nil for bullets.
    case list(start: Int?, items: [ListItem])
    case code(language: String?, code: String)
    case quote(String)
    /// `header` is empty when the table has no `|---|` separator row.
    case table(header: [String], rows: [[String]])
    case rule

    struct ListItem: Equatable {
        /// 0 for top-level items, 1 for items nested one level, and so on.
        let depth: Int
        let text: String
    }

    static func parse(_ markdown: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var index = 0
        var paragraph: [String] = []

        func flushParagraph() {
            let text = paragraph.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                blocks.append(.paragraph(text))
            }
            paragraph = []
        }

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                flushParagraph()
                index += 1
            } else if let fence = codeFence(trimmed) {
                flushParagraph()
                var code: [String] = []
                index += 1
                while index < lines.count, !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix(fence.marker) {
                    code.append(lines[index])
                    index += 1
                }
                index += 1 // Skips the closing fence, if there is one.
                blocks.append(.code(language: fence.language, code: code.joined(separator: "\n")))
            } else if let heading = heading(trimmed) {
                flushParagraph()
                blocks.append(heading)
                index += 1
            } else if isRule(trimmed) {
                flushParagraph()
                blocks.append(.rule)
                index += 1
            } else if trimmed.hasPrefix(">") {
                flushParagraph()
                var quote: [String] = []
                while index < lines.count {
                    let quoteLine = lines[index].trimmingCharacters(in: .whitespaces)
                    guard quoteLine.hasPrefix(">") else { break }
                    quote.append(String(quoteLine.dropFirst()).trimmingCharacters(in: .whitespaces))
                    index += 1
                }
                blocks.append(.quote(quote.joined(separator: "\n")))
            } else if trimmed.hasPrefix("|") {
                flushParagraph()
                var rows: [[String]] = []
                while index < lines.count {
                    let row = lines[index].trimmingCharacters(in: .whitespaces)
                    guard row.hasPrefix("|") else { break }
                    rows.append(tableCells(row))
                    index += 1
                }
                if rows.count >= 2, isSeparatorRow(rows[1]) {
                    blocks.append(.table(header: rows[0], rows: Array(rows.dropFirst(2))))
                } else {
                    blocks.append(.table(header: [], rows: rows))
                }
            } else if let first = listItem(line) {
                flushParagraph()
                var items: [ListItem] = []
                let start = first.number
                while index < lines.count {
                    let current = lines[index]
                    if let item = listItem(current), (item.number == nil) == (start == nil) || item.depth > 0 {
                        items.append(ListItem(depth: item.depth, text: item.text))
                        index += 1
                    } else if !current.trimmingCharacters(in: .whitespaces).isEmpty,
                              current.hasPrefix("  "), let last = items.popLast() {
                        // An indented line continues the previous item.
                        let continued = current.trimmingCharacters(in: .whitespaces)
                        items.append(ListItem(depth: last.depth, text: last.text + "\n" + continued))
                        index += 1
                    } else {
                        break
                    }
                }
                blocks.append(.list(start: start, items: items))
            } else {
                paragraph.append(line)
                index += 1
            }
        }
        flushParagraph()
        return blocks
    }

    /// The text of `markdown` without any markup, e.g. for a one-line preview.
    static func plainText(_ markdown: String) -> String {
        parse(markdown).compactMap { block -> String? in
            switch block {
            case let .heading(_, text), let .paragraph(text), let .quote(text):
                return inlinePlainText(text)
            case let .list(_, items):
                return items.map { inlinePlainText($0.text) }.joined(separator: "\n")
            case let .code(_, code):
                return code
            case let .table(header, rows):
                return ([header] + rows).filter { !$0.isEmpty }.map { $0.map(inlinePlainText).joined(separator: " ") }.joined(separator: "\n")
            case .rule:
                return nil
            }
        }
        .joined(separator: "\n")
    }

    private static func inlinePlainText(_ text: String) -> String {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        guard let attributed = try? AttributedString(markdown: text, options: options) else { return text }
        return String(attributed.characters)
    }

    // MARK: - Lines

    private static func tableCells(_ row: String) -> [String] {
        var cells = row.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        if cells.first?.isEmpty == true { cells.removeFirst() }
        if cells.last?.isEmpty == true { cells.removeLast() }
        return cells
    }

    private static func isSeparatorRow(_ cells: [String]) -> Bool {
        !cells.isEmpty && cells.allSatisfy { cell in
            cell.contains("-") && cell.allSatisfy { "-:".contains($0) }
        }
    }

    private static func codeFence(_ line: String) -> (marker: String, language: String?)? {
        for marker in ["```", "~~~"] where line.hasPrefix(marker) {
            let language = line.dropFirst(marker.count).trimmingCharacters(in: .whitespaces)
            return (marker, language.isEmpty ? nil : language)
        }
        return nil
    }

    private static func heading(_ line: String) -> MarkdownBlock? {
        let hashes = line.prefix { $0 == "#" }.count
        guard (1 ... 6).contains(hashes) else { return nil }
        let rest = line.dropFirst(hashes)
        guard rest.isEmpty || rest.first == " " else { return nil }
        let text = rest.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            .trimmingCharacters(in: .whitespaces)
        return .heading(level: hashes, text: text)
    }

    private static func isRule(_ line: String) -> Bool {
        let compact = line.replacingOccurrences(of: " ", with: "")
        guard compact.count >= 3, let first = compact.first, "-*_".contains(first) else { return false }
        return compact.allSatisfy { $0 == first }
    }

    /// A bullet (`-`, `*`, `+`) or numbered (`1.`, `1)`) list line. Every two spaces of
    /// indentation (or a tab) is one level of nesting.
    private static func listItem(_ line: String) -> (depth: Int, number: Int?, text: String)? {
        let indentation = line.prefix { $0 == " " || $0 == "\t" }
        let depth = indentation.reduce(0) { $0 + ($1 == "\t" ? 2 : 1) } / 2
        let rest = line.dropFirst(indentation.count)

        if let marker = rest.first, "-*+".contains(marker), rest.dropFirst().first == " " {
            let text = rest.dropFirst(2).trimmingCharacters(in: .whitespaces)
            return (depth, nil, text)
        }
        let digits = rest.prefix { $0.isNumber }
        guard !digits.isEmpty, digits.count <= 9, let number = Int(digits) else { return nil }
        let afterDigits = rest.dropFirst(digits.count)
        guard let delimiter = afterDigits.first, delimiter == "." || delimiter == ")",
              afterDigits.dropFirst().first == " " else { return nil }
        let text = afterDigits.dropFirst(2).trimmingCharacters(in: .whitespaces)
        return (depth, number, text)
    }
}
