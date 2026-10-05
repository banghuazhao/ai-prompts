//
// Created by Banghua Zhao on 05/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import AppIntents
import SwiftUI
import WidgetKit

/// Control Center, Lock Screen and Action button control that opens a random prompt (iOS 18+).
@available(iOS 18.0, *)
struct RandomPromptControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: WidgetShared.Kind.randomPromptControl) {
            ControlWidgetButton(action: OpenRandomPromptIntent()) {
                Label("Random Prompt", systemImage: "sparkles")
            }
        }
        .displayName("Random Prompt")
        .description("Open AI Prompts on a random prompt for inspiration.")
    }
}
