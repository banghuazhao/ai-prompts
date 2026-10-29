import Foundation

/// Launch controls for capturing the real app UI on a dedicated development simulator.
/// Release builds and physical devices always use the normal launch flow.
enum ScreenshotLaunchConfiguration {
    static var isEnabled: Bool {
        #if DEBUG && targetEnvironment(simulator)
        ProcessInfo.processInfo.environment["APP_STORE_SCREENSHOTS"] == "1"
        #else
        false
        #endif
    }

    static var initialTab: Int {
        guard isEnabled else { return 0 }
        switch ProcessInfo.processInfo.environment["APP_STORE_SCREENSHOT_TAB"] {
        case "vibe": return 1
        case "favorites": return 2
        case "more": return 3
        case "search": return 4
        default: return 0
        }
    }

    static var initialSearchQuery: String {
        guard isEnabled else { return "" }
        return ProcessInfo.processInfo.environment["APP_STORE_SCREENSHOT_QUERY"] ?? ""
    }
}
