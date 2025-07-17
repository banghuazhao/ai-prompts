# AI Prompts

A Swift iOS app for managing, browsing, and sharing AI prompts. This project is inspired by [f/awesome-chatgpt-prompts](https://github.com/f/awesome-chatgpt-prompts), a popular collection of curated prompts for ChatGPT and other LLM tools.

## Features

- Browse curated AI prompts and "vibe" prompts
- Mark prompts as favorites for quick access
- View prompt details, including contributor info and tech stack
- Modular architecture (e.g., MoreApps module for app recommendations)
- Local data management using GRDB
- Multilingual support (English, Simplified Chinese, Traditional Chinese)
- Modern SwiftUI interface

## Getting Started

### Prerequisites

- Xcode 14 or later
- Swift 5.7+
- iOS 17.0+

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/banghuazhao/ai-prompts.git
   cd ai-prompts
   ```
2. Open `AIPrompts.xcodeproj` in Xcode.
3. Run the project on your simulator or device.

### Project Structure

- `AIPrompts/App/` – App entry point and main views
- `AIPrompts/Components/` – SwiftUI components (Favorites, Prompts, VibePrompt, etc.)
- `AIPrompts/Model/` – Data models (Prompt, VibePrompt)
- `AIPrompts/Service/` – Data management (e.g., DataManager)
- `AIPrompts/Modules/MoreApps/` – Modular feature for app recommendations
- `AIPrompts/Doc/` – CSV files for prompt data
- `AIPrompts/Assets.xcassets/` – App icons and assets

## Data Model Example

```swift
struct VibePrompt: Identifiable, Hashable {
    let id: Int
    var app: String
    var prompt: String
    var contributor: String
    var techstack: String
    var isFavorite: Bool
    // ...
}
```

## Contributing

Contributions are welcome! Please open issues or pull requests for new prompts, features, or bug fixes.

## License

[MIT](LICENSE) (or specify your license)

## Author

- [banghuazhao](https://github.com/banghuazhao)

## Inspiration

This project is inspired by [f/awesome-chatgpt-prompts](https://github.com/f/awesome-chatgpt-prompts), a curated collection of useful prompts for ChatGPT and other LLM tools. 