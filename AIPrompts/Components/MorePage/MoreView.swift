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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 28) {
                        meSection
                        moreFeatureView
                        othersView
                        appInfo
                    }
                    .padding(.vertical, 16)
                }
                .scrollDismissesKeyboard(.immediately)
                if !model.purchaseManager.isPremiumUserPurchased {
                    BannerView()
                        .frame(height: 50)
                        .padding(.bottom, AppSpacing.medium)
                }
            }
            .background(AIStudioPalette.canvas.ignoresSafeArea())
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $model.showPurchaseSheet) {
                PurchaseSheet()
            }
        }
    }

    private var meSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 14) {
                Button {
                    Haptics.shared.vibrateIfEnabled()
                    model.onTapEmojiPicker()
                } label: {
                    Text(model.userAvatar)
                        .font(.system(size: 32))
                        .frame(width: 58, height: 58)
                        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 19))
                        .overlay(RoundedRectangle(cornerRadius: 19).strokeBorder(.white.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Choose your avatar")
                .sheet(isPresented: $model.showEmojiPicker) {
                    EmojiPickerView(selectedEmoji: Binding(model.$userAvatar), title: String(localized: "Choose your avatar"))
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("YOUR SPACE")
                        .font(.caption2.weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(AIStudioPalette.cyan)
                    TextField(
                        "Your Name",
                        text: Binding(model.$userName),
                        prompt: Text("Your Name").foregroundColor(.white.opacity(0.9))
                    )
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .tint(.white)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .accessibilityLabel("Your Name")
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 12) {
                collectionStat(value: model.promptsCount, title: "Prompts")
                collectionStat(value: model.vibePromptsCount, title: "Vibe prompts")
            }

            if !model.isPremiumUser {
                Button {
                    Haptics.shared.vibrateIfEnabled()
                    model.onTapPurchase()
                } label: {
                    Label("Upgrade to Premium", systemImage: "sparkles")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AIStudioPalette.ink)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Label("Welcome, Premium user!", systemImage: "crown.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(.white.opacity(0.15), in: Capsule())
            }
        }
        .padding(22)
        .background(AIStudioPalette.heroGradient, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.horizontal, 16)
    }

    private func collectionStat(value: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 17))
        .accessibilityElement(children: .combine)
    }

    private var moreFeatureView: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading("Explore", subtitle: "Tools for better prompts")
            LazyVGrid(columns: gridColumns, spacing: 12) {
                NavigationLink(destination: SettingView()) {
                    moreItem(icon: "gearshape", title: String(localized: "Settings"))
                }
                .buttonStyle(.plain)
                NavigationLink(destination: ContextEngineeringInfoView()) {
                    moreItem(icon: "brain.head.profile", title: String(localized: "Context Engineering"))
                }
                .buttonStyle(.plain)
                NavigationLink(destination: PromptEngineeringBestPracticesView()) {
                    moreItem(icon: "lightbulb", title: String(localized: "Prompt Engineering"))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    private var othersView: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading("Connect", subtitle: "Share and support")
            LazyVGrid(columns: gridColumns, spacing: 12) {
                NavigationLink(destination: MoreAppsView()) {
                    moreItem(icon: "square.grid.2x2", title: String(localized: "More Apps"))
                }
                .buttonStyle(.plain)
                Button {
                    model.onTapRateUs(openURL: openURL)
                } label: {
                    moreItem(icon: "star", title: String(localized: "Rate Us"))
                }
                .buttonStyle(.plain)
                Button {
                    model.onTapFeedback(openURL: openURL)
                } label: {
                    moreItem(icon: "envelope", title: String(localized: "Feedback"))
                }
                .buttonStyle(.plain)
                if let appURL = model.onTapShareApp() {
                    ShareLink(item: appURL) {
                        moreItem(icon: "square.and.arrow.up", title: String(localized: "Share App"))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func sectionHeading(_ title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .bold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func moreItem(icon: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(model.themeManager.current.primaryColor)
                .frame(width: 46, height: 46)
                .background(model.themeManager.current.primaryColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 15))
                .accessibilityHidden(true)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .padding(16)
        .background(AIStudioPalette.surface, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 21, style: .continuous).strokeBorder(AIStudioPalette.border, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var appInfo: some View {
        VStack(spacing: 3) {
            Text("AI Prompts  ·  AI Prompt Directory")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Button {
                model.onTapCheckForUpdates(openURL: openURL)
            } label: {
                Text("Version \(model.appVersion) · Check for Updates")
                    .font(.footnote)
                    .foregroundStyle(model.themeManager.current.primaryColor)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
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
