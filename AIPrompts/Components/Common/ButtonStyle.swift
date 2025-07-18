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
