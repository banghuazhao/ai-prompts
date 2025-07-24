//
//  MoreView.swift
//  AIPrompts
//
//  Created by Lulin Yang on 2025/7/18.
//

import Dependencies
import MoreApps
import SharingGRDB
import SwiftUI

@Observable
@MainActor
class MeViewModel: HashableObject {
    @ObservationIgnored
    @Shared(.appStorage("userName")) var userName: String = String(localized: "Your Name")
    @ObservationIgnored
    @Shared(.appStorage("userAvatar")) var userAvatar: String = "😀"

    @ObservationIgnored
    @Dependency(\.themeManager) var themeManager

    @ObservationIgnored
    @Dependency(\.appRatingService) var appRatingService

    @ObservationIgnored
    @Dependency(\.purchaseManager) var purchaseManager

    @ObservationIgnored
    @FetchAll(Prompt.all) var allPrompts

    @ObservationIgnored
    @FetchAll(VibePrompt.all) var allVibePrompts

    var showPurchaseSheet = false
    var showEmojiPicker = false

    var promptsCount: String {
        "\(allPrompts.count)"
    }

    var vibePromptsCount: String {
        "\(allVibePrompts.count)"
    }

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    var appName: String {
        Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Unknown"
    }

    var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "no app build version"
    }

    func onTapRateUs(openURL: OpenURLAction) {
        if let url = URL(string: "https://itunes.apple.com/app/id\(Constants.AppID.thisAppID)?action=write-review") {
            openURL(url)
        }
    }

    func onTapFeedback(openURL: OpenURLAction) {
        let email = SupportEmail()
        email.send(openURL: openURL)
    }

    func onTapCheckForUpdates(openURL: OpenURLAction) {
        if let url = URL(string: "https://apps.apple.com/app/id\(Constants.AppID.thisAppID)") {
            openURL(url)
        }
    }

    func onTapShareApp() -> URL? {
        URL(string: "https://itunes.apple.com/app/id\(Constants.AppID.thisAppID)")
    }

    func onTapEmojiPicker() {
        showEmojiPicker = true
    }

    var isPremiumUser: Bool {
        purchaseManager.isPremiumUserPurchased
    }

    func onTapPurchase() {
        showPurchaseSheet = true
    }
}

struct MoreView: View {
    @State private var model = MeViewModel()
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.large) {
                    meSection

                    moreFeatureView

                    othersView

                    // App info section (moved below othersView)
                    VStack(spacing: 4) {
                        Text("AI Prompts  |  AI Prompt Directory")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                        Button {
                            model.onTapCheckForUpdates(openURL: openURL)
                        } label: {
                            Text("v\(model.appVersion)  Check for Updates")
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                            Button {
                                model.onTapCheckForUpdates(openURL: openURL)
                            } label: {
                                Text("v\(model.appVersion)  Check for Updates")
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                                    .underline()
                            }
                        }
                    }
                    .padding(.vertical)
                }
                if !model.purchaseManager.isPremiumUserPurchased {
                    BannerView()
                        .frame(height: 50)
                        .padding(.bottom, AppSpacing.medium)
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $model.showPurchaseSheet) {
                PurchaseSheet()
            }
        }
    }

    private var meSection: some View {
        // Me Section
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack(spacing: AppSpacing.medium) {
                Button(action: {
                    Haptics.shared.vibrateIfEnabled()
                    model.onTapEmojiPicker()
                }) {
                    Text(model.userAvatar)
                        .font(.system(size: 40))
                        .frame(width: 50, height: 50)
                        .background(model.themeManager.current.card)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .sheet(isPresented: $model.showEmojiPicker) {
                    EmojiPickerView(selectedEmoji: $model.userAvatar, title: String(localized: "Choose your avatar"))
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                }
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Your Name", text: $model.userName)
                        .font(AppFont.headline)
                        .fontWeight(.bold)
                        .padding(AppSpacing.small)
                        .background(model.themeManager.current.background)
                        .cornerRadius(AppCornerRadius.button)
                        .lineLimit(1)
                }
                Spacer()
            }
            HStack {
                VStack {
                    Text(model.promptsCount)
                        .font(.headline)
                    Text("Prompts")
                        .font(.caption)
                }
                Divider()
                VStack {
                    Text(model.vibePromptsCount)
                        .font(.headline)
                    Text("Vibe Prompts")
                        .font(.caption)
                }
            }

            if !model.isPremiumUser {
                Button(action: {
                    Haptics.shared.vibrateIfEnabled()
                    model.onTapPurchase()
                }) {
                    Text(String(localized: "Upgrade to Premium"))
                        .appButtonStyle(theme: model.themeManager.current)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                        .font(.title3)
                    Text(String(localized: "Welcome, Premium user!"))
                        .font(.headline)
                        .foregroundColor(model.themeManager.current.primaryColor)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(model.themeManager.current.card)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.button)
                        .stroke(model.themeManager.current.primaryColor, lineWidth: 1.5)
                )
                .cornerRadius(AppCornerRadius.button)
                .shadow(color: AppShadow.card.color, radius: 4, x: 0, y: 2)
            }
        }
        .appCardStyle(theme: model.themeManager.current)
        .padding(.horizontal)
    }

    private var moreFeatureView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text(String(localized: "More Features"))
                .appSectionHeader(theme: model.themeManager.current)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: AppSpacing.large) {
                NavigationLink(destination: SettingView()) {
                    featureItem(icon: "gear", title: String(localized: "Settings"))
                }
                NavigationLink(destination: ContextEngineeringInfoView()) {
                    moreItem(icon: "brain.head.profile", title: String(localized: "Context Engineering"))
                }
                NavigationLink(destination: PromptEngineeringBestPracticesView()) {
                    moreItem(icon: "lightbulb", title: String(localized: "Prompt Engineering"))
                }
            }
        }
        .padding(.horizontal)
    }

    private var othersView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Others")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 24) {
                NavigationLink(destination: MoreAppsView()) {
                    moreItem(icon: "storefront", title: String(localized: "More Apps"))
                }
                Button {
                    model.onTapRateUs(openURL: openURL)
                } label: {
                    moreItem(icon: "star.fill", title: String(localized: "Rate Us"))
                }
                Button {
                    model.onTapFeedback(openURL: openURL)
                } label: {
                    moreItem(icon: "envelope.fill", title: String(localized: "Feedback"))
                }
                if let appURL = model.onTapShareApp() {
                    ShareLink(item: appURL) {
                        moreItem(icon: "square.and.arrow.up", title: String(localized: "Share App"))
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func moreItem(icon: String, title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(model.themeManager.current.primaryColor)
                .frame(width: 36, height: 36)
                .clipShape(Circle())
            Text(title)
                .font(.caption)
                .foregroundColor(model.themeManager.current.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.small)
        .background(model.themeManager.current.card)
        .cornerRadius(AppCornerRadius.card)
        .shadow(color: AppShadow.card.color, radius: AppShadow.card.radius, x: AppShadow.card.x, y: AppShadow.card.y)
    }

    private func featureItem(icon: String, title: String) -> some View {
        VStack(spacing: AppSpacing.small) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(model.themeManager.current.primaryColor)
                .frame(width: 36, height: 36)
                .clipShape(Circle())
            Text(title)
                .font(AppFont.caption)
                .foregroundColor(model.themeManager.current.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.small)
        .background(model.themeManager.current.card)
        .cornerRadius(AppCornerRadius.card)
        .shadow(color: AppShadow.card.color, radius: AppShadow.card.radius, x: AppShadow.card.x, y: AppShadow.card.y)
    }
}

#Preview {
    MoreView()
}

struct SupportEmail {
    let toAddress = "appsbayarea@gmail.com"
    let subject: String = String(localized: "\("AI Prompts") - \("Feedback")")
    var body: String { """
      Application Name: \(Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Unknown")
      iOS Version: \(UIDevice.current.systemVersion)
      Device Model: \(UIDevice.current.model)
      App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "no app version")
      App Build: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "no app build version")

      \(String(localized: "Please describe your issue below"))
      ------------------------------------

    """ }

    func send(openURL: OpenURLAction) {
        let replacedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        let replacedBody = body.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        let urlString = "mailto:\(toAddress)?subject=\(replacedSubject)&body=\(replacedBody)"
        guard let url = URL(string: urlString) else { return }
        openURL(url) { accepted in
            if !accepted { // e.g. Simulator
                print("Device doesn't support email.\n \(body)")
            }
        }
    }
}
