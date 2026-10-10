//
// Created by Banghua Zhao on 10/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI

extension View {
    /// Swipe right to favorite, swipe left to copy or delete.
    ///
    /// Delete only asks for confirmation (the caller shows the alert), so it deliberately isn't
    /// `role: .destructive`, which would animate the row away before the user confirmed.
    func promptSwipeActions(
        isFavorite: Bool,
        onFavorite: @escaping () -> Void,
        onCopy: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        self
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    Haptics.shared.vibrateIfEnabled()
                    onFavorite()
                } label: {
                    Label(isFavorite ? "Unfavorite" : "Favorite", systemImage: isFavorite ? "heart.slash" : "heart")
                }
                .tint(isFavorite ? .gray : .pink)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button {
                    Haptics.shared.vibrateIfEnabled()
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)

                Button {
                    Haptics.shared.vibrateIfEnabled()
                    onCopy()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .tint(AIStudioPalette.violet)
            }
    }
}
