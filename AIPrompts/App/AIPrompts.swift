import GoogleMobileAds
import SharingGRDB
import SwiftUI
import UIKit

@main
struct AIPrompts: App {
    @StateObject private var openAd = OpenAd()
    @Environment(\.scenePhase) private var scenePhase
    @Dependency(\.purchaseManager) private var purchaseManager

    init() {
        // Make all List (UITableView) backgrounds transparent globally
        UITableView.appearance().backgroundColor = .clear
        UITableViewCell.appearance().backgroundColor = .clear
        AppUsage.registerLaunch()
        AppAppearance.migrateLegacySetting()
        prepareDependencies {
            $0.defaultDatabase = AppDatabase.shared
        }
        // Intents shared with the widget extension (the Control Center control) open prompts through this.
        WidgetShared.openDeepLink = { url in
            DeepLinkRouter.shared.handle(url)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    purchaseManager.startObservingTransactions()
                    await purchaseManager.checkPurchaseStatus()
                }
                .task {
                    await ConsentManager.shared.gatherConsentAndStartAds()
                    openAd.requestAppOpenAd()
                }
                .task {
                    await ContentSync.run(database: AppDatabase.shared)
                    WidgetSnapshotWriter.update(database: AppDatabase.shared)
                    AIPromptsShortcuts.updateAppShortcutParameters()
                    await SpotlightIndexer.update()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    print("scenePhase: \(newPhase)")
                    if newPhase == .active {
                        if !purchaseManager.isPremiumUserPurchased {
                            openAd.tryToPresentAd()
                        }
                        openAd.appHasEnterBackgroundBefore = false
                    } else if newPhase == .background {
                        openAd.appHasEnterBackgroundBefore = true
                        AppUsage.noteDidEnterBackground()
                        // Favorites may have changed while the app was open.
                        WidgetSnapshotWriter.update(database: AppDatabase.shared)
                        Task {
                            await SpotlightIndexer.update()
                        }
                    }
                }
        }
    }
}
