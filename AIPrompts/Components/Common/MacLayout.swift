import SwiftUI

/// On Mac, keeps scrolling content in a centered, readable column instead of
/// stretching phone-style cards across a wide window. No effect on iPhone or iPad.
struct ReadableContentWidth: ViewModifier {
    enum Container {
        /// `List` uses the larger of the safe-area inset (the sidebar) and the content margin.
        case list
        /// `ScrollView` adds the content margin to the safe-area inset.
        case scrollView
    }

    var container: Container = .list
    var maxWidth: CGFloat = 900
    @State private var layout = Layout()

    struct Layout: Equatable {
        var width: CGFloat = 0
        var insets = EdgeInsets()
    }

    func body(content: Content) -> some View {
        #if targetEnvironment(macCatalyst)
        let extra = max(0, (layout.width - maxWidth) / 2)
        let leading = container == .list ? layout.insets.leading + extra : extra
        let trailing = container == .list ? layout.insets.trailing + extra : extra
        content
            .contentMargins(.leading, leading, for: .scrollContent)
            .contentMargins(.trailing, trailing, for: .scrollContent)
            .onGeometryChange(for: Layout.self) {
                Layout(width: $0.size.width, insets: $0.safeAreaInsets)
            } action: { layout = $0 }
        #else
        content
        #endif
    }
}

extension View {
    func readableContentWidth(_ container: ReadableContentWidth.Container = .list, maxWidth: CGFloat = 900) -> some View {
        modifier(ReadableContentWidth(container: container, maxWidth: maxWidth))
    }

    /// On Mac, centers a whole screen in a readable column. For screens whose header sits outside the scrolling list.
    @ViewBuilder
    func readableFrameWidth(_ maxWidth: CGFloat = 900) -> some View {
        #if targetEnvironment(macCatalyst)
        frame(maxWidth: maxWidth).frame(maxWidth: .infinity)
        #else
        self
        #endif
    }

    /// Mac shows the tabs as a sidebar, the native Mac layout; iPhone and iPad keep the floating tab bar.
    @available(iOS 26.0, *)
    @ViewBuilder
    func platformTabStyle() -> some View {
        #if targetEnvironment(macCatalyst)
        tabViewStyle(.sidebarAdaptable)
        #else
        tabBarMinimizeBehavior(.onScrollDown)
        #endif
    }
}
