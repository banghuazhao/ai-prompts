//
// Created by Banghua Zhao on 25/09/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import Dependencies
import UIKit

/// Central place for the "happy path" actions on a prompt, so every entry point
/// feeds the ad policy and the rating prompt the same way.
@MainActor
enum PromptActions {
    static func copy(_ text: String) {
        UIPasteboard.general.string = text
        AppUsage.noteOutboundAction()
        registerPositiveAction()
    }

    static func open(_ url: URL) {
        AppUsage.noteOutboundAction()
        UIApplication.shared.open(url)
        registerPositiveAction()
    }

    static func share() {
        AppUsage.noteOutboundAction()
        registerPositiveAction()
    }

    static func favoriteToggled(isFavorite: Bool) {
        if isFavorite {
            registerPositiveAction()
        }
    }

    static func registerPositiveAction() {
        @Dependency(\.appRatingService) var appRatingService
        appRatingService.incrementPrepareTriggerCount()
    }
}
