//
//  SettingView.swift
//  AIPrompts
//
//  Created by Lulin Yang on 2025/7/18.
//



import SharingGRDB
import SwiftUI
import Dependencies
import UniformTypeIdentifiers

struct SettingView: View {
    @AppStorage("buttonSoundEnabled") private var buttonSoundEnabled: Bool = true
    @AppStorage("vibrateEnabled") private var vibrateEnabled: Bool = true
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system
    @AppStorage("showContextEngineeringTips") private var showContextEngineeringTips: Bool = true
    @Dependency(\.themeManager) var themeManager
    
    @Dependency(\.purchaseManager) var purchaseManager
    @Dependency(\.defaultDatabase) private var database
    @ObservedObject private var consent = ConsentManager.shared
    @Environment(\.openURL) private var openURL

    @State private var backupDocument: LibraryBackupDocument?
    @State private var isExportingBackup = false
    @State private var isImportingBackup = false
    @State private var pendingRestore: LibraryBackup?
    @State private var backupMessage: BackupMessage?

    private struct BackupMessage: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    /// Backups are a few hundred KB; anything far bigger isn't one.
    private static let maxBackupFileSize = 50 * 1024 * 1024

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: AppSpacing.large) {
                    settingsSection(title: "Feedback") {
                        Toggle(isOn: $vibrateEnabled) {
                            Text(String(localized: "Vibrate"))
                                .font(AppFont.body)
                                .foregroundColor(themeManager.current.textPrimary)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: themeManager.current.primaryColor))
                    }
                    settingsSection(title: "Appearance") {
                        Picker("Appearance", selection: $appearance) {
                            ForEach(AppAppearance.allCases) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: appearance) { _, _ in
                            Haptics.shared.vibrateIfEnabled()
                        }
                    }
                    settingsSection(title: "Prompt Creation") {
                        Toggle(isOn: $showContextEngineeringTips) {
                            Text(String(localized: "Show Context Engineering Tips"))
                                .font(AppFont.body)
                                .foregroundColor(themeManager.current.textPrimary)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: themeManager.current.primaryColor))
                    }
                    settingsSection(title: "Backup") {
                        Button {
                            Haptics.shared.vibrateIfEnabled()
                            exportBackup()
                        } label: {
                            linkRow("Export Library")
                        }
                        .fileExporter(
                            isPresented: $isExportingBackup,
                            document: backupDocument,
                            contentType: .json,
                            defaultFilename: LibraryBackup.defaultFilename
                        ) { result in
                            backupDocument = nil
                            if case let .failure(error) = result {
                                backupMessage = BackupMessage(title: String(localized: "Export Failed"), message: error.localizedDescription)
                            }
                        }

                        Button {
                            Haptics.shared.vibrateIfEnabled()
                            isImportingBackup = true
                        } label: {
                            linkRow("Restore from Backup")
                        }
                        .fileImporter(isPresented: $isImportingBackup, allowedContentTypes: [.json]) { result in
                            switch result {
                            case let .success(url):
                                readBackup(at: url)
                            case let .failure(error):
                                backupMessage = BackupMessage(title: String(localized: "Restore Failed"), message: error.localizedDescription)
                            }
                        }

                        Text("Save your prompts, favorites, categories and chats to a file, then restore them on any device. Restoring adds to your library and never deletes anything.")
                            .font(.footnote)
                            .foregroundColor(themeManager.current.textPrimary.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    settingsSection(title: "Privacy") {
                        if consent.privacyOptionsRequired {
                            Button {
                                consent.presentPrivacyOptions()
                            } label: {
                                linkRow("Privacy Settings")
                            }
                        }
                        Button {
                            if let url = URL(string: "https://apps-bay.github.io/Apps-Bay-Website/privacy/") {
                                openURL(url)
                            }
                        } label: {
                            linkRow("Privacy Policy")
                        }
                    }
                }
                .padding()
            }
            if !purchaseManager.isPremiumUserPurchased {
                BannerView()
                    .frame(height: 50)
                    .padding(.bottom, 16)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "Restore Backup?",
            isPresented: Binding(
                get: { pendingRestore != nil },
                set: { if !$0 { pendingRestore = nil } }
            ),
            presenting: pendingRestore
        ) { backup in
            Button("Restore") {
                restore(backup)
            }
            Button("Cancel", role: .cancel) {}
        } message: { backup in
            Text("This backup has \(backup.promptCount) prompts, \(backup.vibePromptCount) vibe prompts and \(backup.chatCount) chats. Prompts with the same title are updated to the backup's version and the rest are added. Nothing is deleted.")
        }
        .alert(item: $backupMessage) { message in
            Alert(title: Text(message.title), message: Text(message.message), dismissButton: .default(Text("OK")))
        }
    }

    private func exportBackup() {
        do {
            let data = try LibraryBackup.make(database: database).encoded()
            backupDocument = LibraryBackupDocument(data: data)
            isExportingBackup = true
        } catch {
            backupMessage = BackupMessage(title: String(localized: "Export Failed"), message: error.localizedDescription)
        }
    }

    private func readBackup(at url: URL) {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard fileSize <= Self.maxBackupFileSize else { throw LibraryBackup.BackupError.notABackup }
            pendingRestore = try LibraryBackup.decode(Data(contentsOf: url))
        } catch {
            backupMessage = BackupMessage(title: String(localized: "Restore Failed"), message: error.localizedDescription)
        }
    }

    private func restore(_ backup: LibraryBackup) {
        do {
            let summary = try backup.restore(into: database)
            backupMessage = BackupMessage(
                title: String(localized: "Restore Complete"),
                message: String(localized: "\(summary.added) items added, \(summary.updated) updated.")
            )
            WidgetSnapshotWriter.update(database: database)
            Task {
                await SpotlightIndexer.update()
            }
        } catch {
            backupMessage = BackupMessage(title: String(localized: "Restore Failed"), message: error.localizedDescription)
        }
    }

    private func linkRow(_ title: LocalizedStringKey) -> some View {
        HStack {
            Text(title)
                .font(AppFont.body)
                .foregroundColor(themeManager.current.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundColor(themeManager.current.textPrimary.opacity(0.5))
        }
        .contentShape(Rectangle())
    }

    private func settingsSection<Content: View>(title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(title)
                .appSectionHeader(theme: themeManager.current)
            VStack(spacing: AppSpacing.small) {
                content()
            }
            .padding()
            .glassCard(cornerRadius: AppCornerRadius.card, fallback: themeManager.current.card)
        }
    }
}
