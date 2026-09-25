//
// Created by Banghua Zhao on 25/09/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI
import WidgetKit

@main
struct AIPromptsWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PromptOfTheDayWidget()
        FavoritePromptsWidget()
    }
}

extension View {
    /// Shared widget background: a soft tint in the app's gradient colors.
    func promptWidgetBackground() -> some View {
        containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.purple.opacity(0.18), Color.cyan.opacity(0.12), Color.pink.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
