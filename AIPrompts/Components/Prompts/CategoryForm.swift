//
// Created by Banghua Zhao on 24/07/2025
// Copyright Apps Bay Limited. All rights reserved.
//
  
import Dependencies
import SharingGRDB
import SwiftUI
import SwiftUINavigation

@Observable
@MainActor
class CategoryFormModel: HashableObject {
    @ObservationIgnored
    @FetchAll(PromptCategory.all, animation: .default) var allCategories

    @ObservationIgnored
    @Dependency(\.defaultDatabase) var database

    var selectedCategory: PromptCategory.ID?
    let onSelect: (PromptCategory?) -> Void

    var isEditing = false

    var newCategory = PromptCategory.Draft()

    init(selectedCategory: PromptCategory.ID?, onSelect: @escaping (PromptCategory?) -> Void) {
        self.selectedCategory = selectedCategory
        self.onSelect = onSelect
    }

    func onTapAddCategory() {
        guard !newCategory.title.isEmpty else { return }
        withErrorReporting {
            try database.write { db in
                try PromptCategory
                    .insert { newCategory }
                    .execute(db)
            }
            newCategory = PromptCategory.Draft()
        }
    }

    func onTapDeleteCategory(_ category: PromptCategory) {
        withErrorReporting {
            try database.write { db in
                try PromptCategory
                    .delete(category)
                    .execute(db)
            }
            if category.id == selectedCategory {
                selectedCategory = nil
            }
        }
    }

    // Add update method for category title
    func onUpdateCategory(_ category: PromptCategory, newTitle: String) {
        guard !newTitle.isEmpty, newTitle != category.title else { return }
        withErrorReporting {
            try database.write { db in
                var updated = category
                updated.title = newTitle
                try PromptCategory.update(updated).execute(db)
            }
        }
    }
}

struct CategoryFormView: View {
    @State var model: CategoryFormModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if !model.isEditing {
                        Button {
                            Haptics.shared.vibrateIfEnabled()
                            model.onSelect(nil)
                            dismiss()
                        } label: {
                            HStack {
                                Text("💬 All")
                                Spacer()
                                if model.selectedCategory == nil {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(model.allCategories) { category in
                        if model.isEditing {
                            HStack {
                                TextField(
                                    "✨ Enter New Category",
                                    text: Binding(
                                        get: { category.title },
                                        set: { model.onUpdateCategory(category, newTitle: $0) }
                                    )
                                )
                                Spacer()
                                Button(role: .destructive) {
                                    Haptics.shared.vibrateIfEnabled()
                                    model.onTapDeleteCategory(category)
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        } else {
                            Button {
                                Haptics.shared.vibrateIfEnabled()
                                model.onSelect(category)
                            } label: {
                                HStack {
                                    Text(category.title)
                                    Spacer()
                                    if category.id == model.selectedCategory {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.green)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Haptics.shared.vibrateIfEnabled()
                                    model.onTapDeleteCategory(category)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    HStack {
                        // Title input
                        TextField("✨ Enter New Category", text: $model.newCategory.title)
                        Spacer()
                        Button {
                            Haptics.shared.vibrateIfEnabled()
                            model.onTapAddCategory()
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                } footer: {
                    if model.allCategories.count > 0 {
                        Text("Note: When a category is deleted, all prompts in that category will be moved to '💬 All' category.")
                            .font(AppFont.footnote)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        Haptics.shared.vibrateIfEnabled()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(model.isEditing ? "Done" : "Edit") {
                        Haptics.shared.vibrateIfEnabled()
                        withAnimation {
                            model.isEditing.toggle()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    CategoryFormView(
        model: CategoryFormModel(selectedCategory: nil, onSelect: { _ in })
    )
}
