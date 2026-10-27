//
// Created by Banghua Zhao on 27/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

@testable import AIPrompts
import Foundation
import Testing

struct LLMProviderTests {
    @Test func queryCharactersAreEscaped() throws {
        let url = try #require(LLMProvider.chatGPT.url(for: "a&b=c #d+e/f?g"))
        let string = url.absoluteString
        #expect(string.hasPrefix("https://chatgpt.com/?prompt="))
        #expect(string.hasSuffix("a%26b%3Dc%20%23d%2Be%2Ff%3Fg"))
    }

    @Test func everyProviderBuildsAURLForMultilineUnicodeText() {
        for provider in LLMProvider.allCases {
            let url = provider.url(for: "第一行\nSecond line — “quoted” 😀")
            #expect(url != nil, "\(provider.label)")
            #expect(url?.scheme == "https", "\(provider.label)")
        }
    }

    @Test func orderedKeepsSavedOrderAndAppendsNewProviders() {
        let ordered = LLMProvider.ordered("claude,unknown,chatGPT,claude")
        #expect(Array(ordered.prefix(2)) == [.claude, .chatGPT])
        #expect(ordered.count == LLMProvider.allCases.count)
        #expect(Set(ordered) == Set(LLMProvider.allCases))
    }

    @Test func emptySavedOrderUsesTheDefaultOrder() {
        #expect(LLMProvider.ordered("") == LLMProvider.allCases)
    }

    @Test func hiddenProvidersRoundTrip() {
        let stored = LLMProvider.store([.grok, .perplexity])
        #expect(stored == "grok,perplexity")
        #expect(LLMProvider.hidden(stored + ",bogus") == [.grok, .perplexity])
    }
}
