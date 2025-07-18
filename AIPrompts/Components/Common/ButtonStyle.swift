//
//  ButtonStyle.swift
//  AIPrompts
//
//  Created by Lulin Yang on 2025/7/18.
//

//
// Created by Banghua Zhao on 08/07/2025
// Copyright Apps Bay Limited. All rights reserved.
//
  

import SwiftUI
import SafariServices

// MARK: - ButtonStyles
struct AppCircularButtonStyle: ButtonStyle {
    let theme: AppTheme
    let overrideColor: Color?
    
    init(theme: AppTheme = ThemeManager.shared.current, overrideColor: Color? = nil) {
        self.theme = theme
        self.overrideColor = overrideColor
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.headline)
            .frame(width: 38, height: 38)
            .background(
                (overrideColor?.opacity(0.1) ?? theme.primaryColor.opacity(0.1))
            )
            .foregroundColor(overrideColor ?? theme.primaryColor)
            .clipShape(Circle())
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

struct AppWhiteCircularButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.headline)
            .frame(width: 38, height: 38)
            .background(
                Color.black.opacity(0.1)
            )
            .foregroundColor(Color.white)
            .clipShape(Circle())
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

struct AppRectButtonStyle: ButtonStyle {
    let theme: AppTheme
    
    init(theme: AppTheme = ThemeManager.shared.current) {
        self.theme = theme
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.headline)
            .frame(height: 38)
            .padding(.horizontal, AppSpacing.medium)
            .background(theme.primaryColor.opacity(0.1))
            .foregroundColor(theme.primaryColor)
            .clipShape(
                RoundedRectangle(cornerRadius: 18)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

struct LLMQuickLaunchButtonStyle: ButtonStyle {
    let backgroundColor: Color
    let foregroundColor: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.headline)
            .padding(.vertical, AppSpacing.small)
            .padding(.horizontal, AppSpacing.small)
            .background(backgroundColor.opacity(configuration.isPressed ? 0.8 : 1.0))
            .foregroundColor(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.button, style: .continuous))
            .shadow(color: Color.black.opacity(0.07), radius: 4, x: 0, y: 2)
    }
}

// MARK: - ButtonStyle Convenience Extensions
extension ButtonStyle where Self == AppCircularButtonStyle {
    static var appCircular: AppCircularButtonStyle {
        AppCircularButtonStyle()
    }
}

extension ButtonStyle where Self == AppWhiteCircularButtonStyle {
    static var appWhiteCircular: AppWhiteCircularButtonStyle {
        AppWhiteCircularButtonStyle()
    }
}

extension ButtonStyle where Self == AppRectButtonStyle {
    static var appRect: AppRectButtonStyle {
        AppRectButtonStyle()
    }
    
    
}

extension ButtonStyle where Self == LLMQuickLaunchButtonStyle {
    static func llmQuickLaunch(background: Color, foreground: Color = .white) -> LLMQuickLaunchButtonStyle {
        LLMQuickLaunchButtonStyle(backgroundColor: background, foregroundColor: foreground)
    }
}

extension Color {
    static let chatGPT = Color(red: 0.11, green: 0.82, blue: 0.60) // Green
    static let grok = Color(red: 0.20, green: 0.20, blue: 0.20) // Black
    static let claude = Color(red: 0.98, green: 0.80, blue: 0.20) // Yellow
    static let perplexity = Color(red: 0.18, green: 0.29, blue: 0.97) // Blue
    static let gemini = Color(red: 0.13, green: 0.47, blue: 0.98) // Google Blue
}

struct LLMQuickLaunchButton: View {
    let icon: String
    let label: String
    let background: Color
    let foreground: Color
    let url: URL
    
    var body: some View {
        Button(action: {
            UIApplication.shared.open(url)
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(label)
            }
        }
        .buttonStyle(.llmQuickLaunch(background: background, foreground: foreground))
        .accessibilityLabel("Quick launch to \(label)")
    }
}
