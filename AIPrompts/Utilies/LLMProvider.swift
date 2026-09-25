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
        case .grok: "https://grok.x.ai/?q="
        case .claude: "https://claude.ai/chat?prompt="
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

/// A horizontally scrolling row of quick launch buttons for every `LLMProvider`.
struct LLMQuickLaunchSection: View {
    let prompt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Launch")
                .font(AppFont.headline)
                .foregroundColor(.secondary)
                .padding(.bottom, 2)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.small) {
                    ForEach(LLMProvider.allCases) { provider in
                        if let url = provider.url(for: prompt) {
                            LLMQuickLaunchButton(
                                icon: provider.icon,
                                label: provider.label,
                                background: provider.background,
                                foreground: provider.foreground,
                                url: url
                            )
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}
