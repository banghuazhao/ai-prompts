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
            return Color(red: 0.914, green: 0.420, blue: 0.369)
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

    var backgroundColor: Color {
        switch self {
        case .default:
            return Color(red: 0.98, green: 0.95, blue: 0.94) // Light warm background
        case .blue:
            return Color(red: 0.95, green: 0.97, blue: 1.0) // Light blue background
        case .green:
            return Color(red: 0.94, green: 0.98, blue: 0.95) // Light green background
        case .purple:
            return Color(red: 0.97, green: 0.95, blue: 1.0) // Light purple background
        case .pink:
            return Color(red: 0.99, green: 0.95, blue: 0.97) // Light pink background
        case .orange:
            return Color(red: 1.0, green: 0.97, blue: 0.94) // Light orange background
        }
    }
}

// MARK: - Base Theme

struct BaseTheme: AppTheme {
    let primaryColor: Color
    let secondaryGray = Color(red: 0.56, green: 0.56, blue: 0.58) // #8E8E93
    let background: Color
    let card = Color.white
    let success = Color(red: 0.20, green: 0.78, blue: 0.35) // #34C759
    let warning = Color(red: 1.0, green: 0.80, blue: 0.0) // #FFCC00
    let error = Color(red: 1.0, green: 0.23, blue: 0.19) // #FF3B30
    let textPrimary = Color(red: 0.11, green: 0.11, blue: 0.12) // #1C1C1E
    let textSecondary = Color(red: 0.56, green: 0.56, blue: 0.58) // #8E8E93

    init(themeColor: ThemeColor) {
        primaryColor = themeColor.primaryColor
        background = themeColor.backgroundColor
    }
}

struct DarkBaseTheme: AppTheme {
    let primaryColor: Color
    let secondaryGray = Color(red: 0.56, green: 0.56, blue: 0.58)
    let background = Color(red: 0.10, green: 0.10, blue: 0.12) // #1A1A1F
    let card = Color(red: 0.16, green: 0.16, blue: 0.18) // #29292E
    let success = Color(red: 0.20, green: 0.78, blue: 0.35)
    let warning = Color(red: 1.0, green: 0.80, blue: 0.0)
    let error = Color(red: 1.0, green: 0.23, blue: 0.19)
    let textPrimary = Color.white
    let textSecondary = Color(red: 0.7, green: 0.7, blue: 0.75)

    init(themeColor: ThemeColor) {
        primaryColor = themeColor.primaryColor
    }
}

// MARK: - Theme Manager

@Observable
class ThemeManager: ObservableObject {
    var current: AppTheme {
        let themeColor = ThemeColor(rawValue: selectedThemeColor) ?? .default
        return darkModeEnabled ?
            DarkBaseTheme(themeColor: themeColor) :
            BaseTheme(themeColor: themeColor)
    }

    @ObservationIgnored
    @Shared(.appStorage("darkModeEnabled")) private var darkModeEnabledStorage: Bool = false

    var darkModeEnabled: Bool { darkModeEnabledStorage }

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

    func updateTheme(darkMode: Bool) {
        $darkModeEnabledStorage.withLock {
            $0 = darkMode
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

struct AppFont {
    static let largeTitle = Font.system(size: 34, weight: .bold)
    static let title = Font.system(size: 28, weight: .semibold)
    static let title2 = Font.system(size: 22, weight: .semibold)
    static let title3 = Font.system(size: 19, weight: .semibold)
    static let headline = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 17, weight: .regular)
    static let subheadline = Font.system(size: 15, weight: .regular)
    static let subheadlineSemibold = Font.system(size: 15, weight: .semibold)
    static let caption = Font.system(size: 13, weight: .regular)
    static let footnote = Font.system(size: 12, weight: .regular)
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
