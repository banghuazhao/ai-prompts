import Sharing
import SwiftUI

/// Chat assistants that a prompt can be launched into directly.
enum LLMProvider: String, CaseIterable, Identifiable {
    case chatGPT
    case grok
    case claude
    case perplexity
    case gemini

    var id: String { rawValue }

    var label: String {
        switch self {
        case .chatGPT: "ChatGPT"
        case .grok: "Grok"
        case .claude: "Claude"
        case .perplexity: "Perplexity"
        case .gemini: "Gemini"
        }
    }

    var icon: String {
        switch self {
        case .chatGPT: "message.fill"
        case .grok: "bolt.fill"
        case .claude: "sun.max.fill"
        case .perplexity: "questionmark.circle.fill"
        case .gemini: "sparkles"
        }
    }

    var background: Color {
        switch self {
        case .chatGPT: .chatGPT
        case .grok: .grok
        case .claude: .claude
        case .perplexity: .perplexity
        case .gemini: .gemini
        }
    }

    var foreground: Color {
        self == .claude ? .black : .white
    }

    private var baseURL: String {
        switch self {
        case .chatGPT: "https://chatgpt.com/?prompt="
        case .grok: "https://grok.com/?q="
        case .claude: "https://claude.ai/new?q="
        case .perplexity: "https://www.perplexity.ai/?q="
        case .gemini: "https://gemini.google.com/app?prompt="
        }
    }

    /// Only RFC 3986 unreserved characters are left unescaped, so `&`, `+`, `=`, `#`
    /// and friends inside a prompt don't break the query string.
    private static let queryValueAllowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    func url(for prompt: String) -> URL? {
        let encoded = prompt.addingPercentEncoding(withAllowedCharacters: Self.queryValueAllowed) ?? ""
        return URL(string: baseURL + encoded)
    }
}

// MARK: - Preferences

extension SharedKey where Self == AppStorageKey<String>.Default {
    /// Every provider's raw value, comma separated, in the order Quick Launch shows them.
    static var quickLaunchOrder: Self {
        Self[.appStorage("quickLaunchOrder"), default: ""]
    }

    /// Raw values of the providers Quick Launch hides, comma separated.
    static var hiddenQuickLaunchProviders: Self {
        Self[.appStorage("hiddenQuickLaunchProviders"), default: ""]
    }
}

extension SharedKey where Self == AppStorageKey<LLMProvider>.Default {
    /// The assistant behind "Open in …" on prompt rows. It's always shown in Quick Launch.
    static var defaultLLMProvider: Self {
        Self[.appStorage("defaultLLMProvider"), default: .chatGPT]
    }
}

extension LLMProvider {
    /// All providers in the saved order. Providers added in later versions go at the end.
    static func ordered(_ storedOrder: String) -> [LLMProvider] {
        var providers: [LLMProvider] = []
        for provider in storedOrder.split(separator: ",").compactMap({ LLMProvider(rawValue: String($0)) })
        where !providers.contains(provider) {
            providers.append(provider)
        }
        return providers + allCases.filter { !providers.contains($0) }
    }

    static func hidden(_ storedHidden: String) -> Set<LLMProvider> {
        Set(storedHidden.split(separator: ",").compactMap { LLMProvider(rawValue: String($0)) })
    }

    static func store(_ providers: some Sequence<LLMProvider>) -> String {
        providers.map(\.rawValue).joined(separator: ",")
    }
}

// MARK: - Views

/// The text to launch for a prompt from a list or detail page: the prompt as written, or with
/// its blanks filled from remembered values. Nil while a blank still needs the user's input.
func launchablePrompt(_ prompt: String) -> String? {
    let template = PromptTemplate(prompt)
    return template.hasVariables ? template.runnablePrompt : prompt
}

/// "Open in …" for context menus, using the default assistant. When the prompt has blanks
/// without values it calls `onNeedsBlanks` instead, e.g. to show the Customize sheet.
struct OpenInDefaultLLMButton: View {
    let prompt: String
    let onNeedsBlanks: () -> Void
    /// Called after the assistant opens, e.g. to record the prompt as used.
    var onLaunch: (() -> Void)? = nil

    @Shared(.defaultLLMProvider) private var provider

    var body: some View {
        if let launchable = launchablePrompt(prompt) {
            if let url = provider.url(for: launchable) {
                Button {
                    Haptics.shared.vibrateIfEnabled()
                    PromptActions.open(url)
                    onLaunch?()
                } label: {
                    Label("Open in \(provider.label)", systemImage: provider.icon)
                }
            }
        } else {
            Button {
                Haptics.shared.vibrateIfEnabled()
                onNeedsBlanks()
            } label: {
                Label("Open in \(provider.label)…", systemImage: provider.icon)
            }
        }
    }
}

/// A horizontally scrolling row of quick launch buttons for the assistants the user picked
/// in Settings, in their order.
struct LLMQuickLaunchSection: View {
    let prompt: String
    /// Called after a provider is launched, e.g. to record the prompt as used.
    var onLaunch: (() -> Void)? = nil
    /// When set, blanks are filled from remembered values before launching, and this is called
    /// instead of launching while a blank still has none. When nil, `prompt` is launched as is.
    var onNeedsBlanks: (() -> Void)? = nil

    @Shared(.quickLaunchOrder) private var order
    @Shared(.hiddenQuickLaunchProviders) private var hidden
    @Shared(.defaultLLMProvider) private var defaultProvider

    private var providers: [LLMProvider] {
        let hidden = LLMProvider.hidden(hidden)
        return LLMProvider.ordered(order).filter { $0 == defaultProvider || !hidden.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Launch")
                .font(AppFont.headline)
                .foregroundColor(.secondary)
                .padding(.bottom, 2)
            ScrollView(.horizontal, showsIndicators: false) {
                GlassGroup(spacing: AppSpacing.small) {
                    HStack(spacing: AppSpacing.small) {
                        ForEach(providers) { provider in
                            LLMQuickLaunchButton(
                                icon: provider.icon,
                                label: provider.label,
                                background: provider.background,
                                foreground: provider.foreground
                            ) {
                                launch(provider)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 2)
                }
            }
            .scrollClipDisabled()
        }
    }

    private func launch(_ provider: LLMProvider) {
        let text: String
        if let onNeedsBlanks {
            guard let launchable = launchablePrompt(prompt) else {
                onNeedsBlanks()
                return
            }
            text = launchable
        } else {
            text = prompt
        }
        guard let url = provider.url(for: text) else { return }
        PromptActions.open(url)
        onLaunch?()
    }
}
