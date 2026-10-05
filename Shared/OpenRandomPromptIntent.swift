//
// Created by Banghua Zhao on 05/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import AppIntents
import Foundation

/// Opens the app on a random prompt. Used by the Control Center control.
///
/// Compiled into both the app and the widget extension: the control references it from the
/// extension, and because it opens the app, the system performs it in the app process.
struct OpenRandomPromptIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Random Prompt"
    static var description = IntentDescription("Opens AI Prompts on a random prompt for inspiration.")
    static var openAppWhenRun = true

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        if let item = WidgetShared.loadSnapshot()?.daily.randomElement() {
            WidgetShared.openDeepLink?(item.deepLink)
        }
        return .result()
    }
}
