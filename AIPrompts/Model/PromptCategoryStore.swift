//
// Created by Banghua Zhao on 08/07/2025
// Copyright Apps Bay Limited. All rights reserved.
//
  

import Foundation

struct PromptCategoryStore {
    // Reduced set of example default categories for seeding, each prefixed with an emoji
    static let seed: [PromptCategory.Draft] = [
        .init(title: "✨ General"),
        .init(title: "💼 Productivity"),
        .init(title: "✍️ Writing"),
        .init(title: "🎉 Fun"),
        .init(title: "📚 Learning"),
        .init(title: "🤖 AI & Tech"),
        .init(title: "🧠 Creativity"),
        .init(title: "🗣️ Conversation")
    ]
}
