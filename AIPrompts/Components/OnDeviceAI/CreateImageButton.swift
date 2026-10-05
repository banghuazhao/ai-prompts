//
// Created by Banghua Zhao on 05/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import ImagePlayground
import SwiftUI

/// Turns text into a picture with Image Playground (iOS 18.1+, Apple Intelligence devices).
/// Shows nothing where Image Playground isn't available.
struct CreateImageButton<Label: View>: View {
    let text: String
    let title: String
    @ViewBuilder let label: () -> Label

    var body: some View {
        if #available(iOS 18.1, *) {
            ImagePlaygroundLauncher(text: text, title: title, label: label)
        }
    }
}

extension CreateImageButton where Label == SwiftUI.Label<Text, Image> {
    init(text: String, title: String) {
        self.init(text: text, title: title) {
            SwiftUI.Label("Create Image", systemImage: "paintpalette")
        }
    }
}

@available(iOS 18.1, *)
private struct ImagePlaygroundLauncher<Label: View>: View {
    let text: String
    let title: String
    let label: () -> Label

    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    @State private var isPresented = false
    @State private var createdImage: CreatedImage?

    var body: some View {
        if supportsImagePlayground {
            Button {
                Haptics.shared.vibrateIfEnabled()
                isPresented = true
            } label: {
                label()
            }
            .imagePlaygroundSheet(
                isPresented: $isPresented,
                concepts: [.extracted(from: String(text.prefix(2000)), title: title)]
            ) { url in
                // The file is temporary, so load it right away.
                if let image = UIImage(contentsOfFile: url.path) {
                    createdImage = CreatedImage(image: image, title: title)
                    PromptActions.registerPositiveAction()
                }
            }
            .sheet(item: $createdImage) { createdImage in
                CreatedImageSheet(createdImage: createdImage)
            }
        }
    }
}

private struct CreatedImage: Identifiable {
    let id = UUID()
    let image: UIImage
    let title: String
}

private struct CreatedImageSheet: View {
    let createdImage: CreatedImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Image(uiImage: createdImage.image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding()
                .frame(maxHeight: .infinity)
                .navigationTitle(createdImage.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            Haptics.shared.vibrateIfEnabled()
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(
                            item: Image(uiImage: createdImage.image),
                            preview: SharePreview(createdImage.title, image: Image(uiImage: createdImage.image))
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .simultaneousGesture(TapGesture().onEnded { PromptActions.share() })
                    }
                }
        }
    }
}

extension String {
    /// Whether a prompt is about making pictures, so offering Image Playground makes sense.
    var looksLikeImagePrompt: Bool {
        let lower = lowercased()
        return ["image", "midjourney", "dall-e", "dalle", "stable diffusion", "illustration", "picture", "photo", "drawing", "painting", "artwork", "logo"]
            .contains { lower.contains($0) }
    }
}

/// Card-style label for creating an image from an image prompt on a detail page.
struct ImagePlaygroundCardLabel: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "paintpalette.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    LinearGradient(colors: [.blue, .teal, .green], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )
            VStack(alignment: .leading, spacing: 2) {
                Text("Create Image")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("Turn this prompt into a picture with Image Playground")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .glassCard(interactive: true, fallback: Color(.systemBackground))
    }
}
