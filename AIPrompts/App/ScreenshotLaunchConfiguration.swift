import Foundation

/// Launch controls for capturing the real app UI on a development simulator or Debug Mac build.
/// Release builds and physical iPhones/iPads always use the normal launch flow.
enum ScreenshotLaunchConfiguration {
    static var isEnabled: Bool {
        #if DEBUG && (targetEnvironment(simulator) || targetEnvironment(macCatalyst))
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

#if DEBUG && targetEnvironment(macCatalyst)
import ImageIO
import ScreenCaptureKit
import UIKit
import UniformTypeIdentifiers

extension ScreenshotLaunchConfiguration {
    /// 1440×900 points captures at 2x as 2880×1800, an accepted Mac App Store screenshot size.
    static let macWindowSize = CGSize(width: 1440, height: 900)

    /// Pins the Mac window to the screenshot size. When APP_STORE_SCREENSHOT_OUTPUT is set,
    /// the app captures its own window (toolbar included) to that PNG path and quits.
    @MainActor
    static func prepareMacWindowAndCapture() async {
        guard isEnabled,
              let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        scene.sizeRestrictions?.minimumSize = macWindowSize
        scene.sizeRestrictions?.maximumSize = macWindowSize

        let environment = ProcessInfo.processInfo.environment
        guard let output = environment["APP_STORE_SCREENSHOT_OUTPUT"] else { return }
        let delay = Double(environment["APP_STORE_SCREENSHOT_DELAY"] ?? "") ?? 6
        // Bring the window to the front so it is captured in its active state.
        UIApplication.shared.activateSceneSession(for: UISceneSessionActivationRequest(session: scene.session))
        try? await Task.sleep(for: .seconds(delay))

        if #available(macCatalyst 18.2, *) {
            do {
                try await captureOwnWindow(to: URL(fileURLWithPath: output))
            } catch {
                print("Screenshot capture failed: \(error)")
            }
        }
        exit(0)
    }

    /// ScreenCaptureKit can capture this app's own window without screen-recording permission,
    /// including the AppKit-drawn toolbar that a UIKit snapshot misses.
    @available(macCatalyst 18.2, *)
    private static func captureOwnWindow(to url: URL) async throws {
        let content = try await SCShareableContent.currentProcess
        guard let window = content.windows
            .filter(\.isOnScreen)
            .max(by: { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height })
        else { throw CocoaError(.fileNoSuchFile) }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        let scale = CGFloat(filter.pointPixelScale)
        configuration.width = Int(filter.contentRect.width * scale)
        configuration.height = Int(filter.contentRect.height * scale)
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)

        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }
}
#endif
