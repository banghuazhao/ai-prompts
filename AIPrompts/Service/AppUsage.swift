//
// Created by Banghua Zhao on 25/09/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import Foundation

/// Lightweight usage signals shared by the ad and rating logic.
enum AppUsage {
    private static let defaults = UserDefaults.standard

    private enum Key {
        static let firstLaunchDate = "firstLaunchDate"
        static let lastOutboundActionDate = "lastOutboundActionDate"
        static let lastBackgroundDate = "lastBackgroundDate"
        static let lastAppOpenAdDate = "lastAppOpenAdDate"
        static let lastDeepLinkDate = "lastDeepLinkDate"
    }

    static func registerLaunch() {
        if defaults.object(forKey: Key.firstLaunchDate) == nil {
            defaults.set(Date(), forKey: Key.firstLaunchDate)
        }
    }

    static var firstLaunchDate: Date {
        defaults.object(forKey: Key.firstLaunchDate) as? Date ?? Date()
    }

    /// Call when the user does something that is expected to take them out of the app
    /// (copying a prompt, quick launching an LLM, sharing).
    static func noteOutboundAction() {
        defaults.set(Date(), forKey: Key.lastOutboundActionDate)
    }

    static func noteDidEnterBackground() {
        defaults.set(Date(), forKey: Key.lastBackgroundDate)
    }

    /// Opening the app from a widget, Shortcut or Siri should land on the prompt, not an ad.
    static func noteDeepLinkOpened() {
        defaults.set(Date(), forKey: Key.lastDeepLinkDate)
    }

    static func noteAppOpenAdPresented() {
        defaults.set(Date(), forKey: Key.lastAppOpenAdDate)
    }

    // MARK: - App open ad policy

    /// No full-screen ads during the first day after install.
    static let adFreeGracePeriod: TimeInterval = 24 * 60 * 60
    /// Minimum time between two app open ads.
    static let minimumAppOpenAdInterval: TimeInterval = 30 * 60
    /// If the user left the app this soon after copying / launching a prompt,
    /// they were using the app as intended and should not be punished with an ad.
    static let outboundActionWindow: TimeInterval = 3 * 60
    static let deepLinkWindow: TimeInterval = 10

    static var shouldShowAppOpenAd: Bool {
        let now = Date()

        if now.timeIntervalSince(firstLaunchDate) < adFreeGracePeriod {
            return false
        }

        if let lastAd = defaults.object(forKey: Key.lastAppOpenAdDate) as? Date,
           now.timeIntervalSince(lastAd) < minimumAppOpenAdInterval {
            return false
        }

        if let lastDeepLink = defaults.object(forKey: Key.lastDeepLinkDate) as? Date,
           now.timeIntervalSince(lastDeepLink) < deepLinkWindow {
            return false
        }

        if let lastOutbound = defaults.object(forKey: Key.lastOutboundActionDate) as? Date {
            let backgroundDate = defaults.object(forKey: Key.lastBackgroundDate) as? Date ?? now
            let leftAfterOutboundAction = backgroundDate.timeIntervalSince(lastOutbound)
            if leftAfterOutboundAction >= 0 && leftAfterOutboundAction < outboundActionWindow {
                return false
            }
        }

        return true
    }
}
