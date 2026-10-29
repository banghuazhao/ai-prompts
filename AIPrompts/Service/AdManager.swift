//
//  AdManager.swift
//  TimesMatter
//
//  Created by Lulin Yang on 2025/7/11.
//

#if !targetEnvironment(macCatalyst)
import GoogleMobileAds
import SwiftUI
import OSLog

private let logger = Logger(subsystem: "AIPrompts", category: "Ads")

enum AdManager {
    static let isSupported = true

    /// Production IDs come from the Release build settings. Google test IDs exist in Debug only;
    /// Release never falls back to them (an unresolved ID stays empty and no ad is requested).
    struct GoogleAdsID {
        #if DEBUG
        static let bannerViewAdUnitID = Bundle.main.object(forInfoDictionaryKey: "bannerViewAdUnitID") as? String ?? "ca-app-pub-3940256099942544/2934735716"
        static let appOpenAdID = Bundle.main.object(forInfoDictionaryKey: "appOpenAdID") as? String ?? "ca-app-pub-3940256099942544/5575463023"
        #else
        static let bannerViewAdUnitID = Bundle.main.object(forInfoDictionaryKey: "bannerViewAdUnitID") as? String ?? ""
        static let appOpenAdID = Bundle.main.object(forInfoDictionaryKey: "appOpenAdID") as? String ?? ""
        #endif
    }
}

@MainActor
final class OpenAd: NSObject, ObservableObject, FullScreenContentDelegate {
    var appOpenAd: AppOpenAd?
    var loadTime = Date()
    var appHasEnterBackgroundBefore = false

    func requestAppOpenAd() {
        guard ConsentManager.shared.adsReady, !AdManager.GoogleAdsID.appOpenAdID.isEmpty else { return }
        let request = ConsentManager.shared.makeRequest()
        AppOpenAd.load(
            with: AdManager.GoogleAdsID.appOpenAdID,
            request: request,
            completionHandler: { appOpenAdIn, error in
                if let error = error {
                    logger.error("App open ad failed to load: \(error.localizedDescription)")
                } else {
                    logger.debug("App open ad is ready")
                }
                self.appOpenAd = appOpenAdIn
                self.appOpenAd?.fullScreenContentDelegate = self
                self.loadTime = Date()
            }
        )
    }

    func tryToPresentAd() {
        logger.debug("tryToPresentAd called")
        guard let gOpenAd = appOpenAd, wasLoadTimeLessThanNHoursAgo(thresholdN: 4) else {
            logger.debug("No app open ad loaded or it expired; requesting a new one")
            requestAppOpenAd()
            return
        }
        guard appHasEnterBackgroundBefore else {
            logger.debug("App hasn't been in the background; not presenting an app open ad")
            return
        }
        // Give a widget / Shortcut deep link a moment to register before deciding.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.presentIfAllowed(gOpenAd)
        }
    }

    private func presentIfAllowed(_ gOpenAd: AppOpenAd) {
        guard AppUsage.shouldShowAppOpenAd else {
            logger.debug("App open ad skipped by ad policy")
            return
        }
        guard var presenter = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .windows.first?.rootViewController else { return }
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        logger.debug("Presenting app open ad")
        gOpenAd.present(from: presenter)
        AppUsage.noteAppOpenAdPresented()
    }

    func wasLoadTimeLessThanNHoursAgo(thresholdN: Int) -> Bool {
        let now = Date()
        let timeIntervalBetweenNowAndLoadTime = now.timeIntervalSince(loadTime)
        let secondsPerHour = 3600.0
        let intervalInHours = timeIntervalBetweenNowAndLoadTime / secondsPerHour
        return intervalInHours < Double(thresholdN)
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        logger.error("App open ad failed to present: \(error.localizedDescription)")
        requestAppOpenAd()
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        logger.debug("App open ad dismissed")
        requestAppOpenAd()
    }
}

struct BannerView: UIViewControllerRepresentable {
    @ObservedObject private var consent = ConsentManager.shared
    @State var viewWidth: CGFloat = .zero
    private let bannerView = GoogleMobileAds.BannerView()
    private let adUnitID = AdManager.GoogleAdsID.bannerViewAdUnitID

    func makeUIViewController(context: Context) -> some UIViewController {
        let bannerViewController = BannerViewController()
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = bannerViewController
        bannerView.delegate = context.coordinator
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        bannerViewController.view.addSubview(bannerView)
        // Constrain GADBannerView to the bottom of the view.
        NSLayoutConstraint.activate([
            bannerView.bottomAnchor.constraint(
                equalTo: bannerViewController.view.safeAreaLayoutGuide.bottomAnchor),
            bannerView.centerXAnchor.constraint(equalTo: bannerViewController.view.centerXAnchor),
        ])
        bannerViewController.delegate = context.coordinator

        return bannerViewController
    }

    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        guard viewWidth != .zero, consent.adsReady, !adUnitID.isEmpty else { return }

        bannerView.adSize = currentOrientationAnchoredAdaptiveBanner(width: viewWidth)
        bannerView.load(consent.makeRequest())
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, BannerViewControllerWidthDelegate, BannerViewDelegate {
        let parent: BannerView

        init(_ parent: BannerView) {
            self.parent = parent
        }

        // MARK: - BannerViewControllerWidthDelegate methods

        func bannerViewController(
            _ bannerViewController: BannerViewController, didUpdate width: CGFloat
        ) {
            parent.viewWidth = width
        }

        // MARK: - BannerViewDelegate methods

        private func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            logger.debug("Banner ad received")
        }

        private func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            logger.error("Banner ad failed: \(error.localizedDescription)")
        }
    }
}

protocol BannerViewControllerWidthDelegate: AnyObject {
    func bannerViewController(_ bannerViewController: BannerViewController, didUpdate width: CGFloat)
}

class BannerViewController: UIViewController {
    weak var delegate: BannerViewControllerWidthDelegate?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        delegate?.bannerViewController(
            self, didUpdate: view.frame.inset(by: view.safeAreaInsets).size.width)
    }

    override func viewWillTransition(
        to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator
    ) {
        coordinator.animate { _ in
            // do nothing
        } completion: { _ in
            self.delegate?.bannerViewController(
                self, didUpdate: self.view.frame.inset(by: self.view.safeAreaInsets).size.width)
        }
    }
}
#else
import SwiftUI

// Google Mobile Ads has no Mac build, so the Mac app runs without ads.
enum AdManager {
    static let isSupported = false
}

@MainActor
final class OpenAd: ObservableObject {
    var appHasEnterBackgroundBefore = false
    func requestAppOpenAd() {}
    func tryToPresentAd() {}
}

struct BannerView: View {
    var body: some View { EmptyView() }
}
#endif
