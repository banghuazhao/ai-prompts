import SwiftUI
import SharingGRDB

@main
struct AIPrompts: App {
    @StateObject private var dataManager = DataManager()
    
    init() {
//        MobileAds.shared.start(completionHandler: nil)
        prepareDependencies {
            $0.defaultDatabase = try! appDatabase()
        }
    }

    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
        }
    }
} 
