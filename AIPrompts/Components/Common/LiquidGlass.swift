import SwiftUI

// Liquid Glass (iOS 26) adoption helpers.
//
// Per Apple's HIG, glass is used for the navigation/control layer that floats above content:
// buttons, chips, floating cards and toolbars. Scrollable content stays on plain surfaces.
// Every helper falls back to the pre-iOS 26 look so the app keeps its iOS 17 deployment target.

// MARK: - Surfaces

extension View {
    /// Wraps the view in a Liquid Glass surface of the given shape.
    ///
    /// Before iOS 26 the surface is `fallback`, a solid fill reproducing the original look
    /// (with the card shadow when `fallbackShadow` is set), or, when `fallback` is nil,
    /// an ultra thin material with `tint` layered on top.
    @ViewBuilder
    func glassSurface<S: Shape>(
        _ shape: S,
        tint: Color? = nil,
        interactive: Bool = false,
        fallback: Color? = nil,
        fallbackShadow: Bool = false
    ) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(Glass.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            background {
                if let fallback {
                    shape
                        .fill(fallback)
                        .shadow(
                            color: fallbackShadow ? AppShadow.card.color : .clear,
                            radius: AppShadow.card.radius,
                            x: AppShadow.card.x,
                            y: AppShadow.card.y
                        )
                } else {
                    ZStack {
                        shape
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
                        if let tint {
                            shape.fill(tint.opacity(0.2))
                        }
                    }
                }
            }
        }
    }

    func glassCard(
        cornerRadius: CGFloat = 20,
        tint: Color? = nil,
        interactive: Bool = false,
        fallback: Color? = nil
    ) -> some View {
        glassSurface(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            tint: tint,
            interactive: interactive,
            fallback: fallback,
            fallbackShadow: true
        )
    }

    func glassCapsule(tint: Color? = nil, interactive: Bool = false, fallback: Color? = nil) -> some View {
        glassSurface(Capsule(), tint: tint, interactive: interactive, fallback: fallback)
    }

    func glassCircle(tint: Color? = nil, interactive: Bool = false, fallback: Color? = nil) -> some View {
        glassSurface(Circle(), tint: tint, interactive: interactive, fallback: fallback)
    }

    /// Small circular glass backing for icon-only buttons on iOS 26; unchanged before.
    @ViewBuilder
    func glassIcon(size: CGFloat = 34) -> some View {
        if #available(iOS 26.0, *) {
            frame(width: size, height: size)
                .glassEffect(Glass.regular.interactive(), in: Circle())
        } else {
            self
        }
    }

    /// Hides a list's opaque background inside a sheet so the iOS 26 glass sheet shows through.
    @ViewBuilder
    func glassSheetBackground() -> some View {
        if #available(iOS 26.0, *) {
            scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}

// MARK: - Content

extension View {
    /// Card behind a prompt row. Rows are scrolling content, so on iOS 26 they sit on a plain
    /// surface underneath the glass controls instead of imitating glass themselves.
    @ViewBuilder
    func promptRowSurface() -> some View {
        if #available(iOS 26.0, *) {
            background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else {
            background(
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    LinearGradient(
                        colors: [Color.purple.opacity(0.10), Color.cyan.opacity(0.08), Color.pink.opacity(0.08), Color.white.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.white.opacity(0.07), radius: 3, x: -3, y: -3)
            .shadow(color: Color.black.opacity(0.10), radius: 3, x: 3, y: 3)
        }
    }
}

// MARK: - Buttons

extension View {
    /// `.glass` / `.glassProminent` on iOS 26, `.bordered` / `.borderedProminent` before.
    @ViewBuilder
    func glassButtonStyle(prominent: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                buttonStyle(.glassProminent)
            } else {
                buttonStyle(.glass)
            }
        } else {
            if prominent {
                buttonStyle(.borderedProminent)
            } else {
                buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Containers

/// Groups nearby glass shapes so they blend and morph together on iOS 26.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat? = nil
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}
