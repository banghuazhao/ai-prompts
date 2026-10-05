//
// Created by Banghua Zhao on 05/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI

/// What goes on a shareable image card.
struct ShareCardContent: Identifiable, Hashable {
    var id: String { title + body }
    let title: String
    let body: String
    /// A small line under the body, e.g. that the text was written by Apple Intelligence.
    var note: String?
}

/// A branded card for a prompt or an answer, rendered to an image for Instagram, X, WeChat and so on.
/// Every shared card advertises the app.
struct ShareCardView: View {
    let content: ShareCardContent

    static let width: CGFloat = 360
    private static let maxBodyLength = 700

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image("appIcon360")
                    .resizable()
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text("AI Prompts")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(content.title)
                .font(.title2.bold())
                .foregroundStyle(.primary)

            Text(Self.trimmed(content.body))
                .font(.callout)
                .lineSpacing(4)
                .foregroundStyle(.primary)

            if let note = content.note {
                Label(note, systemImage: "sparkles")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.purple)
            }

            Divider()

            HStack {
                Text("Get AI Prompts on the App Store")
                    .font(.caption.weight(.semibold))
                Spacer()
                Image(systemName: "arrow.down.app.fill")
                    .foregroundStyle(.blue)
            }
            .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: Self.width, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.16), Color.cyan.opacity(0.12), Color.pink.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .background(Color.white)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .environment(\.colorScheme, .light)
    }

    private static func trimmed(_ text: String) -> String {
        text.count > maxBodyLength ? String(text.prefix(maxBodyLength)) + "…" : text
    }

    @MainActor
    func render() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 3
        return renderer.uiImage
    }
}

/// Previews the card and shares it as an image.
struct ShareCardSheet: View {
    let content: ShareCardContent

    @State private var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    private var appStoreURL: URL {
        URL(string: "https://apps.apple.com/app/id\(Constants.AppID.thisAppID)")!
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                ShareCardView(content: content)
                    .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                    .padding()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Share as Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        Haptics.shared.vibrateIfEnabled()
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let image {
                    ShareLink(
                        item: Image(uiImage: image),
                        subject: Text(content.title),
                        message: Text("Made with AI Prompts \(appStoreURL.absoluteString)"),
                        preview: SharePreview(content.title, image: Image(uiImage: image))
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .glassButtonStyle(prominent: true)
                    .controlSize(.large)
                    .padding()
                    .simultaneousGesture(TapGesture().onEnded { PromptActions.share() })
                }
            }
            .task {
                image = ShareCardView(content: content).render()
            }
        }
    }
}
