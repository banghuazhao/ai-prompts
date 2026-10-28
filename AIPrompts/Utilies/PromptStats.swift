//
// Created by Banghua Zhao on 27/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import Foundation

/// Size of a prompt in words and in estimated model tokens, which is what limits how much
/// an assistant can take in.
struct PromptStats: Equatable {
    let words: Int
    let estimatedTokens: Int

    init(_ text: String) {
        var count = 0
        // Word boundaries come from the system, so languages without spaces are counted too.
        text.enumerateSubstrings(in: text.startIndex..., options: [.byWords, .substringNotRequired]) { _, _, _, _ in
            count += 1
        }
        words = count
        estimatedTokens = text.isEmpty ? 0 : ChatContext.estimatedTokens(text)
    }
}
