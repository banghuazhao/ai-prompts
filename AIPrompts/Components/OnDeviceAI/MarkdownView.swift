//
// Created by Banghua Zhao on 23/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI

/// Renders a Markdown reply block by block: headings, lists, code blocks, quotes and tables,
/// with inline styling inside each block. Safe to use while the reply is still streaming.
struct MarkdownView: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(MarkdownBlock.parse(markdown).enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case let .heading(level, text):
            Text(Self.inline(text))
                .font(Self.headingFont(level))
                .padding(.top, level <= 2 ? 4 : 0)
                .accessibilityAddTraits(.isHeader)
        case let .paragraph(text):
            Text(Self.inline(text))
                .lineSpacing(4)
        case let .list(start, items):
            MarkdownListView(start: start, items: items)
        case let .code(language, code):
            MarkdownCodeBlock(language: language, code: code)
        case let .quote(text):
            Text(Self.inline(text))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 3)
                }
        case let .table(header, rows):
            MarkdownTableView(header: header, rows: rows)
        case .rule:
            Divider()
                .padding(.vertical, 4)
        }
    }

    private static func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .title2.bold()
        case 2: .title3.bold()
        case 3: .headline
        default: .subheadline.bold()
        }
    }

    /// Bold, italics, links and `code` within a block.
    static func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

private struct MarkdownListView: View {
    let start: Int?
    let items: [MarkdownBlock.ListItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(markers.enumerated()), id: \.offset) { index, marker in
                let item = items[index]
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(marker)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(minWidth: start == nil ? 10 : 20, alignment: .trailing)
                    Text(MarkdownView.inline(item.text))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, CGFloat(item.depth) * 18)
            }
        }
    }

    /// Numbers for top-level items of an ordered list, bullets for everything else.
    private var markers: [String] {
        var number = start ?? 1
        return items.map { item in
            if item.depth == 0, start != nil {
                defer { number += 1 }
                return "\(number)."
            }
            return item.depth == 0 ? "•" : "◦"
        }
    }
}

private struct MarkdownTableView: View {
    let header: [String]
    let rows: [[String]]

    private var columnCount: Int {
        ([header] + rows).map(\.count).max() ?? 0
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                if !header.isEmpty {
                    row(header)
                        .font(.subheadline.weight(.semibold))
                    Divider()
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { index, cells in
                    row(cells)
                        .font(.subheadline)
                    if index < rows.count - 1 {
                        Divider()
                            .opacity(0.5)
                    }
                }
            }
            .padding(12)
        }
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func row(_ cells: [String]) -> some View {
        GridRow {
            ForEach(0 ..< columnCount, id: \.self) { column in
                Text(MarkdownView.inline(cells.indices.contains(column) ? cells[column] : ""))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 220, alignment: .leading)
            }
        }
    }
}

private struct MarkdownCodeBlock: View {
    let language: String?
    let code: String

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language ?? String(localized: "Code"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    Haptics.shared.vibrateIfEnabled()
                    PromptActions.copy(code)
                    withAnimation {
                        copied = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            copied = false
                        }
                    }
                } label: {
                    Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(copied ? Color.green : Color.secondary)
                .accessibilityLabel(copied ? "Copied" : "Copy code")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.quaternarySystemFill))

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .fixedSize()
                    .padding(12)
            }
        }
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    ScrollView {
        MarkdownView(markdown: """
        # Weekly plan
        Here is a plan with **three focus blocks** a day and `buffer` time.

        ## Monday
        1. Deep work on the launch
        2. Review *pull requests*
           - Frontend
           - Backend
        3. Gym

        > Keep Friday afternoon free.

        ```swift
        let plan = Plan(days: 5)
        print(plan.summary)
        ```

        | Day | Focus | Hours |
        |-----|-------|------:|
        | Mon | **Launch** | 4 |
        | Tue | Reviews | 2 |

        ---
        - Drink water
        - Sleep by 11
        """)
        .padding()
    }
}
