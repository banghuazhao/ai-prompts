//
// Created by Banghua Zhao on 24/07/2025
// Copyright Apps Bay Limited. All rights reserved.
//

import Dependencies
import SharingGRDB
import SwiftUI

struct CategorySelectionSheet: View {
    @FetchAll(PromptCategory.all) var categories
    @State var selectedCategory: PromptCategory.ID?
    /// Number of prompts in the library, shown next to "All" when set.
    var totalCount: Int? = nil
    /// Number of prompts in each category. Categories missing from it show 0 once any count is set.
    var promptCounts: [PromptCategory.ID: Int]? = nil
    let onSelect: (PromptCategory?) -> Void

    var body: some View {
        List {
            // 'All' option
            Button {
                Haptics.shared.vibrateIfEnabled()
                onSelect(nil)
            } label: {
                HStack {
                    Text("💬 All")
                    Spacer()
                    if let totalCount {
                        count(totalCount)
                    }
                    if selectedCategory == nil {
                        Image(systemName: "checkmark")
                            .foregroundColor(.green)
                    }
                }
                .contentShape(Rectangle()) // Make the whole row tappable
            }
            .buttonStyle(.plain)

            // MARK: - Reusable Context Menu Modifier

            // Category options
            ForEach(categories) { category in
                Button {
                    Haptics.shared.vibrateIfEnabled()
                    selectedCategory = category.id
                    onSelect(category)
                } label: {
                    HStack {
                        Text(category.displayTitle)
                        Spacer()
                        if let promptCounts {
                            count(promptCounts[category.id, default: 0])
                        }
                        if category.id == selectedCategory {
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .glassSheetBackground()
    }

    private func count(_ value: Int) -> some View {
        Text(value, format: .number)
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
            .accessibilityLabel(Text("\(value) prompts"))
    }
}
