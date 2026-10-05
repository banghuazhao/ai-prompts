import SwiftUI

/// A single featured surface gives the prompt libraries a recognizable identity
/// while leaving the scrolling content on calm, readable cards.
struct AIStudioLibraryHero: View {
    let eyebrow: LocalizedStringKey
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let promptCount: Int
    let symbol: String
    let actionTitle: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 28)
                .fill(AIStudioPalette.heroGradient)

            Circle()
                .fill(AIStudioPalette.cyan.opacity(0.25))
                .frame(width: 160, height: 160)
                .blur(radius: 36)
                .offset(x: 55, y: -55)
                .accessibilityHidden(true)

            Image(systemName: symbol)
                .font(.system(size: 92, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.12))
                .rotationEffect(.degrees(-15))
                .offset(x: 14, y: 55)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 12) {
                Label(eyebrow, systemImage: "sparkle")
                    .font(.caption.bold())
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(AIStudioPalette.cyan)

                Text(title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)

                ViewThatFits(in: .horizontal) {
                    heroFooter
                    VStack(alignment: .leading, spacing: 12) {
                        heroCount
                        heroAction
                    }
                }
                .padding(.top, 6)
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(color: AIStudioPalette.violet.opacity(0.20), radius: 18, x: 0, y: 9)
        .accessibilityElement(children: .contain)
    }

    private var heroFooter: some View {
        HStack(spacing: 12) {
            heroCount
            Spacer(minLength: 0)
            heroAction
        }
    }

    private var heroCount: some View {
        Label("\(promptCount) prompts", systemImage: "square.stack.3d.up")
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.white.opacity(0.16), in: Capsule())
    }

    private var heroAction: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(actionTitle)
                Image(systemName: "arrow.up.right")
                    .font(.caption.bold())
            }
            .font(.subheadline.bold())
            .foregroundStyle(AIStudioPalette.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(.white, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
