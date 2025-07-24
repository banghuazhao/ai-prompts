import GoogleMobileAds
import SharingGRDB
import SwiftUI
import UIKit

@main
struct AIPrompts: App {
    @AppStorage("darkModeEnabled") private var darkModeEnabled: Bool = false
    @StateObject private var openAd = OpenAd()
    @Environment(\.scenePhase) private var scenePhase
    @Dependency(\.purchaseManager) private var purchaseManager

    init() {
        // Make all List (UITableView) backgrounds transparent globally
        UITableView.appearance().backgroundColor = .clear
        UITableViewCell.appearance().backgroundColor = .clear
        MobileAds.shared.start(completionHandler: nil)
        prepareDependencies {
            $0.defaultDatabase = try! appDatabase()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(darkModeEnabled ? .dark : .light)
                .onChange(of: scenePhase) { _, newPhase in
                    print("scenePhase: \(newPhase)")
                    if newPhase == .active {
                        if !purchaseManager.isPremiumUserPurchased {
                            openAd.tryToPresentAd()
                        }
                        openAd.appHasEnterBackgroundBefore = false
                    } else if newPhase == .background {
                        openAd.appHasEnterBackgroundBefore = true
                    }
                }
        }
    }
}
