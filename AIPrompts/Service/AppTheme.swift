//
//  AppTheme.swift
//  AIPrompts
//
//  Created by Lulin Yang on 2025/7/18.
//

import Dependencies
import Sharing
import SwiftUI

// MARK: - Theme Protocol

protocol AppTheme {
    var primaryColor: Color { get }
    var secondaryGray: Color { get }
    var background: Color { get }
    var card: Color { get }
    var success: Color { get }
    var warning: Color { get }
    var error: Color { get }
    var textPrimary: Color { get }
    var textSecondary: Color { get }
}

// MARK: - Theme Colors

enum ThemeColor: String, CaseIterable {
    case `default` = "Default"
    case blue = "Blue"
    case green = "Green"
    case purple = "Purple"
    case pink = "Pink"
    case orange = "Orange"

    var displayName: String {
        switch self {
        case .`default`:
            String(localized: "Default")
        case .blue:
            String(localized: "Blue")
        case .green:
            String(localized: "Green")
        case .purple:
            String(localized: "Purple")
        case .pink:
            String(localized: "Pink")
        case .orange:
            String(localized: "Orange")
        }
    }

    var primaryColor: Color {
        switch self {
        case .default:
            return AIStudioPalette.violet
        case .blue:
            return Color(red: 0.0, green: 0.48, blue: 1.0) // #007AFF - Blue
        case .green:
            return Color(red: 0.20, green: 0.78, blue: 0.35) // #34C759 - Green
        case .purple:
            return Color(red: 0.58, green: 0.35, blue: 0.95) // #AF5CF7 - Purple
        case .pink:
            return Color(red: 0.91, green: 0.30, blue: 0.58) // #E84D94 - Pink
        case .orange:
            return Color(red: 1.0, green: 0.58, blue: 0.0) // #FF9400 - Orange
        }
    }

    /// Page background in light appearance. Dark appearance uses one neutral background for every color.
    var lightBackground: UIColor {
        switch self {
        case .default:
            return UIColor(named: "StudioCanvas") ?? .systemGroupedBackground
        case .blue:
            return UIColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 1) // Light blue background
        case .green:
            return UIColor(red: 0.94, green: 0.98, blue: 0.95, alpha: 1) // Light green background
        case .purple:
            return UIColor(red: 0.97, green: 0.95, blue: 1.0, alpha: 1) // Light purple background
        case .pink:
            return UIColor(red: 0.99, green: 0.95, blue: 0.97, alpha: 1) // Light pink background
        case .orange:
            return UIColor(red: 1.0, green: 0.97, blue: 0.94, alpha: 1) // Light orange background
        }
    }
}

// MARK: - AI Studio palette

/// Shared brand colors for the library, prompt details, and discovery screens.
/// The surface colors are asset-backed so cards remain legible in both appearances.
enum AIStudioPalette {
    static let ink = Color(red: 0.075, green: 0.080, blue: 0.19)
    static let violet = Color(red: 0.40, green: 0.31, blue: 0.89)
    static let cyan = Color(red: 0.39, green: 0.88, blue: 0.96)
    static let pink = Color(red: 0.96, green: 0.51, blue: 0.77)
    static let canvas = Color("StudioCanvas")
    static let surface = Color("StudioSurface")
    static let border = Color("StudioBorder")
    static let heroGradient = LinearGradient(
        colors: [ink, Color(red: 0.20, green: 0.15, blue: 0.46), violet],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Appearance

/// Whether the app follows the system's light or dark setting or always uses one of them.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "appearance"

    var id: String { rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }

    /// Up to 1.5 the app had a Dark Mode switch that defaulted to off, which kept the app light even
    /// when the system was dark. Anyone who touched that switch keeps their choice; everyone else
    /// now follows the system.
    static func migrateLegacySetting(in defaults: UserDefaults = .standard) {
        guard defaults.string(forKey: storageKey) == nil else { return }
        let appearance: AppAppearance
        if let darkModeEnabled = defaults.object(forKey: "darkModeEnabled") as? Bool {
            appearance = darkModeEnabled ? .dark : .light
        } else {
            appearance = .system
        }
        defaults.set(appearance.rawValue, forKey: storageKey)
    }

    /// Overrides every window, so sheets, alerts and ads follow the choice too.
    /// `preferredColorScheme(nil)` doesn't reliably hand control back to the system once it was set.
    @MainActor
    func apply() {
        for case let windowScene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = userInterfaceStyle
            }
        }
    }
}

extension Color {
    /// A color that resolves to `light` or `dark` for the appearance it is drawn in.
    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark.resolvedColor(with: traits) : light.resolvedColor(with: traits)
        })
    }
}

// MARK: - Base Theme

/// Colors that switch between light and dark on their own, so views never need to know the appearance.
struct BaseTheme: AppTheme {
    let primaryColor: Color
    let secondaryGray = Color(red: 0.56, green: 0.56, blue: 0.58) // #8E8E93
    let background: Color
    let card = Color.adaptive(
        light: .white,
        dark: UIColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1) // #29292E
    )
    let success = Color(red: 0.20, green: 0.78, blue: 0.35) // #34C759
    let warning = Color(red: 1.0, green: 0.80, blue: 0.0) // #FFCC00
    let error = Color(red: 1.0, green: 0.23, blue: 0.19) // #FF3B30
    let textPrimary = Color.adaptive(
        light: UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1), // #1C1C1E
        dark: .white
    )
    let textSecondary = Color.adaptive(
        light: UIColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1), // #8E8E93
        dark: UIColor(red: 0.7, green: 0.7, blue: 0.75, alpha: 1)
    )

    init(themeColor: ThemeColor) {
        primaryColor = themeColor.primaryColor
        background = Color.adaptive(
            light: themeColor.lightBackground,
            dark: UIColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1) // #1A1A1F
        )
    }
}

// MARK: - Theme Manager

@Observable
class ThemeManager: ObservableObject {
    var current: AppTheme {
        BaseTheme(themeColor: ThemeColor(rawValue: selectedThemeColor) ?? .default)
    }

    @ObservationIgnored
    @Shared(.appStorage("selectedThemeColor")) private var selectedThemeColor: String = ThemeColor.default.rawValue

    static let shared = ThemeManager()

    var currentThemeColor: String {
        return selectedThemeColor
    }

    func updateThemeColor(_ themeColorName: String) {
        $selectedThemeColor.withLock {
            $0 = themeColorName
        }
    }
}

// MARK: - DependencyKey for ThemeManager

private enum ThemeManagerKey: DependencyKey {
    static let liveValue = ThemeManager.shared
}

extension DependencyValues {
    var themeManager: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}

// MARK: - Typography

/// Text styles scale with the reader's text size setting. At the default size they are within a
/// point of the fixed sizes the app used before.
struct AppFont {
    static let largeTitle = Font.system(.largeTitle, weight: .bold)
    static let title = Font.system(.title, weight: .semibold)
    static let title2 = Font.system(.title2, weight: .semibold)
    static let title3 = Font.system(.title3, weight: .semibold)
    static let headline = Font.system(.headline, weight: .semibold)
    static let body = Font.system(.body, weight: .regular)
    static let subheadline = Font.system(.subheadline, weight: .regular)
    static let subheadlineSemibold = Font.system(.subheadline, weight: .semibold)
    static let caption = Font.system(.footnote, weight: .regular)
    static let footnote = Font.system(.caption, weight: .regular)
}

// MARK: - Spacing & Layout

struct AppSpacing {
    static let small: CGFloat = 8
    static let smallMedium: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
}

struct AppCornerRadius {
    static let info: CGFloat = 12
    static let card: CGFloat = 16
    static let button: CGFloat = 12
    static let avatar: CGFloat = 25
}

// MARK: - Shadows

struct AppShadow {
    static let card = ShadowStyle(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
}

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Reusable Modifiers

extension View {
    func appCardStyle(theme: AppTheme = ThemeManager.shared.current) -> some View {
        padding(AppSpacing.medium)
            .background(theme.card)
            .cornerRadius(AppCornerRadius.card)
            .shadow(color: AppShadow.card.color, radius: AppShadow.card.radius, x: AppShadow.card.x, y: AppShadow.card.y)
    }

    func appSectionHeader(theme: AppTheme = ThemeManager.shared.current) -> some View {
        font(AppFont.headline)
            .foregroundColor(theme.textPrimary)
            .padding(.vertical, AppSpacing.small)
    }

    func appBackground(theme: AppTheme = ThemeManager.shared.current) -> some View {
        background(theme.background)
    }

    func appInfoSection(theme: AppTheme = ThemeManager.shared.current) -> some View {
        padding(.vertical, AppSpacing.small)
            .padding(.horizontal, AppSpacing.medium)
            .background(theme.secondaryGray.opacity(0.1))
            .cornerRadius(AppCornerRadius.info)
    }

    func appButtonStyle(theme: AppTheme = ThemeManager.shared.current, filled: Bool = true) -> some View {
        font(AppFont.headline)
            .padding(.vertical, AppSpacing.small)
            .padding(.horizontal, AppSpacing.large)
            .background(filled ? theme.primaryColor : Color.clear)
            .foregroundColor(filled ? .white : theme.primaryColor)
            .cornerRadius(AppCornerRadius.button)
    }
}
