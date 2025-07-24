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
                        Text(category.title)
                        Spacer()
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
    }
}
