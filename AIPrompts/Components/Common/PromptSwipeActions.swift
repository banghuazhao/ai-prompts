//
// Created by Banghua Zhao on 10/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI

extension View {
    /// Swipe right to favorite, swipe left to copy or delete. Deleting can be undone from the
    /// banner that follows, so a full swipe is enough for it.
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
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    Haptics.shared.vibrateIfEnabled()
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }

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
