//
//  AppRatingService.swift
//  AIPrompts
//
//  Created by Lulin Yang on 2025/7/18.
//


import Dependencies
import Foundation
import Sharing
import StoreKit
import SwiftUI

@Observable
class AppRatingService {
    @ObservationIgnored
    @Shared(.appStorage("ratePrepareTriggerCount")) private var ratePrepareTriggerCount: Int = 0
    @ObservationIgnored
    @Shared(.appStorage("lastRatingPromptDate")) private var lastRatingPromptDate: Date?
    @ObservationIgnored
    @Shared(.appStorage("hasRatedApp")) private var hasRatedApp: Bool = false

    // Minimum days between rating prompts (to avoid spam)
    private let minimumDaysBetweenPrompts: TimeInterval = 30 * 24 * 60 * 60 // 30 days

    /// Increments the rate prepare trigger count and checks if we should show a rating prompt
    func incrementPrepareTriggerCount() {
        $ratePrepareTriggerCount.withLock { $0 += 1 }
        print("Rate Prepare Trigger  count: \(ratePrepareTriggerCount)")

        // Check if we should show rating prompt
        checkAndShowRatingPrompt()
    }

    /// Checks if conditions are met to show a rating prompt
    private func checkAndShowRatingPrompt() {
        // Don't show if user has already rated
        guard !hasRatedApp else { return }

        // Don't show if we've shown a prompt recently
        if let lastPrompt = lastRatingPromptDate {
            let daysSinceLastPrompt = Date().timeIntervalSince(lastPrompt)
            if daysSinceLastPrompt < minimumDaysBetweenPrompts {
                return
            }
        }

        // Check if current prepare trigger count matches any threshold
        guard ratePrepareTriggerCount.isMultiple(of: 3) else { return }

        // Show rating prompt
        showRatingPrompt()
    }

    /// Shows the system rating prompt
    private func showRatingPrompt() {
        print("showRatingPrompt")
        // Update last prompt date
        $lastRatingPromptDate.withLock { $0 = Date() }

        // Request review using StoreKit
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.requestRating()
        }
    }

    /// Manually trigger rating prompt (for testing or manual rating button)
    @MainActor
    func requestRating() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        if #available(iOS 18, *) {
            AppStore.requestReview(in: scene)
        } else {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    /// Opens the App Store review page
    func openAppStoreReview() {
        let appID = Constants.AppID.thisAppID
        let reviewURL = "https://itunes.apple.com/app/id\(appID)?action=write-review"

        if let url = URL(string: reviewURL) {
            UIApplication.shared.open(url)
        }
    }

    /// Opens the App Store app page
    func openAppStorePage() {
        let appID = Constants.AppID.thisAppID
        let appURL = "https://apps.apple.com/app/id\(appID)"

        if let url = URL(string: appURL) {
            UIApplication.shared.open(url)
        }
    }

    /// Resets the rating state (for testing purposes)
    func resetRatingState() {
        $ratePrepareTriggerCount.withLock { $0 = 0 }
        $lastRatingPromptDate.withLock { $0 = nil }
        $hasRatedApp.withLock { $0 = false }
    }

    /// Checks if user has rated the app
    var userHasRated: Bool {
        hasRatedApp
    }
}

// MARK: - Dependency Injection

extension DependencyValues {
    var appRatingService: AppRatingService {
        get { self[AppRatingServiceKey.self] }
        set { self[AppRatingServiceKey.self] = newValue }
    }
}

private enum AppRatingServiceKey: DependencyKey {
    static let liveValue = AppRatingService()
}
