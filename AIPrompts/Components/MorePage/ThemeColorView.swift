//
//  ThemeColorView.swift
//  AIPrompts
//
//  Created by Lulin Yang on 2025/7/18.
//



import Dependencies
import SwiftUI

struct ThemeColorView: View {
    @Dependency(\.themeManager) var themeManager
    @Environment(\.dismiss) private var dismiss

    private let themeColors: [ThemeColorOption] = [
        ThemeColorOption(themeColor: .default, color: Color(red: 0.914, green: 0.420, blue: 0.369), icon: "flame.fill"),
        ThemeColorOption(themeColor: .blue, color: Color(red: 0.0, green: 0.48, blue: 1.0), icon: "drop.fill"),
        ThemeColorOption(themeColor: .green, color: Color(red: 0.20, green: 0.78, blue: 0.35), icon: "leaf.fill"),
        ThemeColorOption(themeColor: .purple, color: Color(red: 0.58, green: 0.35, blue: 0.95), icon: "sparkles"),
        ThemeColorOption(themeColor: .pink, color: Color(red: 0.91, green: 0.30, blue: 0.58), icon: "heart.fill"),
        ThemeColorOption(themeColor: .orange, color: Color(red: 1.0, green: 0.58, blue: 0.0), icon: "sun.max.fill"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                Text(String(localized: "Select your preferred primary color for the app"))
                    .font(AppFont.body)
                    .foregroundColor(themeManager.current.textSecondary)
                    .multilineTextAlignment(.center)

                // Theme Color Options
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: AppSpacing.large) {
                    ForEach(themeColors, id: \.themeColor.rawValue) { themeOption in
                        ThemeColorCard(
                            themeOption: themeOption,
                            isSelected: themeManager.currentThemeColor == themeOption.themeColor.rawValue,
                            onTap: {
                                themeManager.updateThemeColor(themeOption.themeColor.rawValue)
                            }
                        )
                    }
                }
                .padding(.horizontal)

                // Preview Section
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    Text(String(localized: "Preview"))
                        .appSectionHeader(theme: themeManager.current)

                    VStack(spacing: AppSpacing.medium) {
                        // Sample button
                        HStack {
                                                    Button(action: {
                            Haptics.shared.vibrateIfEnabled()
                        }) {
                            Text(String(localized: "Sample Button"))
                        }
                            .buttonStyle(.appRect)
                            
                            Button(action: {
                                Haptics.shared.vibrateIfEnabled()
                            }) {
                                Image(systemName: "plus")
                            }
                            .buttonStyle(.appCircular)
                        }

                        // Sample card
                        VStack(alignment: .leading, spacing: AppSpacing.small) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(themeManager.current.primaryColor)
                                Text(String(localized: "Sample Card"))
                                    .font(AppFont.headline)
                                    .foregroundColor(themeManager.current.textPrimary)
                                Spacer()
                            }
                            Text(String(localized: "This is how your selected theme color will look throughout the app."))
                                .font(AppFont.body)
                                .foregroundColor(themeManager.current.textSecondary)
                        }
                        .appCardStyle(theme: themeManager.current)
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("Theme Color")
            .navigationBarTitleDisplayMode(.inline)
        }
        .background(themeManager.current.background)
    }
}

struct ThemeColorOption {
    let themeColor: ThemeColor
    let color: Color
    let icon: String
}

struct ThemeColorCard: View {
    @Dependency(\.themeManager) var themeManager
    let themeOption: ThemeColorOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            Haptics.shared.vibrateIfEnabled()
            onTap()
        }) {
            VStack(spacing: AppSpacing.medium) {
                // Color circle with icon
                ZStack {
                    Circle()
                        .fill(themeOption.color)
                        .frame(width: 50, height: 50)
                        .shadow(color: themeOption.color.opacity(0.3), radius: 8, x: 0, y: 4)

                    Image(systemName: themeOption.icon)
                        .font(.title)
                        .foregroundColor(.white)
                }

                Text(themeOption.themeColor.displayName)
                    .font(AppFont.headline)
                    .foregroundColor(themeOption.color)
            }
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.medium)
            .background(themeManager.current.card)
            .cornerRadius(AppCornerRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.card)
                    .stroke(isSelected ? themeOption.color : Color.clear, lineWidth: 3)
            )
            .shadow(color: AppShadow.card.color, radius: AppShadow.card.radius, x: AppShadow.card.x, y: AppShadow.card.y)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ThemeColorView()
}
