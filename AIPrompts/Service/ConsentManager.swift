//
//  ConsentManager.swift
//  AIPrompts
//
//  Single source of truth for "may we load ads / may we personalize them".
//  Order on every launch: UMP consent (GDPR/UK/CH/US states) -> ATT -> start Mobile Ads.
//  The most restrictive answer wins: ATT not authorized => non-personalized ads only.
//

import AdSupport
import AppTrackingTransparency
import GoogleMobileAds
import SwiftUI
import UserMessagingPlatform

@MainActor
final class ConsentManager: ObservableObject {
    static let shared = ConsentManager()

    /// True once consent + ATT are resolved and the Mobile Ads SDK has been started.
    @Published private(set) var adsReady = false
    @Published private(set) var privacyOptionsRequired = false

    private var isGathering = false

    /// Personalized ads need ATT authorization (UMP purposes are enforced by the SDK itself).
    var mayPersonalizeAds: Bool {
        ATTrackingManager.trackingAuthorizationStatus == .authorized
    }

    /// Every ad request goes through here so a denial is always applied.
    func makeRequest() -> Request {
        let request = Request()
        if !mayPersonalizeAds {
            let extras = Extras()
            extras.additionalParameters = ["npa": "1"]
            request.register(extras)
        }
        request.scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        return request
    }

    /// Runs the full consent sequence. Safe to call repeatedly; only one run is active at a time.
    func gatherConsentAndStartAds() async {
        guard !isGathering, !adsReady else { return }
        isGathering = true
        defer { isGathering = false }

        await waitUntilActive()

        // 1. UMP consent info + form (only shown when required).
        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = false
        #if DEBUG
        // Debug builds only: simulate the EEA with UMP_DEBUG_EEA=1 and start clean with UMP_DEBUG_RESET=1.
        let env = ProcessInfo.processInfo.environment
        if env["UMP_DEBUG_RESET"] == "1" { ConsentInformation.shared.reset() }
        if env["UMP_DEBUG_EEA"] == "1" {
            let debug = DebugSettings()
            debug.geography = .EEA
            parameters.debugSettings = debug
        }
        #endif
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { _ in
                continuation.resume()
            }
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ConsentForm.loadAndPresentIfRequired(from: Self.topViewController()) { _ in
                continuation.resume()
            }
        }
        refreshPrivacyOptions()

        // 2. ATT, only after UMP and only while the app is on screen. Never re-asked after a decision.
        await waitUntilActive()
        #if DEBUG
        print("[CONSENT] UMP status=\(ConsentInformation.shared.consentStatus.rawValue) canRequestAds=\(ConsentInformation.shared.canRequestAds) ATT before=\(ATTrackingManager.trackingAuthorizationStatus.rawValue)")
        #endif
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }
        #if DEBUG
        print("[CONSENT] ATT after=\(ATTrackingManager.trackingAuthorizationStatus.rawValue) npa=\(!mayPersonalizeAds)")
        #endif

        // 3. Start ads only when consent allows requesting them.
        guard ConsentInformation.shared.canRequestAds else { return }
        await MobileAds.shared.start()
        adsReady = true
    }

    /// Reopens the UMP privacy options form (Settings entry point).
    func presentPrivacyOptions() {
        ConsentForm.presentPrivacyOptionsForm(from: Self.topViewController()) { [weak self] _ in
            Task { @MainActor in self?.refreshPrivacyOptions() }
        }
    }

    private func refreshPrivacyOptions() {
        privacyOptionsRequired =
            ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    private func waitUntilActive() async {
        while UIApplication.shared.applicationState != .active {
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
    }

    private static func topViewController() -> UIViewController? {
        var top = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
