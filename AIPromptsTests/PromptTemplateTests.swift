//
// Created by Banghua Zhao on 27/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

@testable import AIPrompts
import Testing

struct PromptTemplateTests {
    @Test func plainTextHasNoVariables() {
        let template = PromptTemplate("Write a haiku about autumn.")
        #expect(!template.hasVariables)
        #expect(template.render([:]) == "Write a haiku about autumn.")
    }

    @Test func mustacheVariablesAreFoundOnceInOrder() {
        let template = PromptTemplate("Explain {{ topic }} to {{audience}}. Keep {{topic}} simple.")
        #expect(template.variables.map(\.id) == ["topic", "audience"])
        #expect(template.variables.allSatisfy { $0.defaultValue.isEmpty })
        let rendered = template.render(["topic": "black holes", "audience": "kids"])
        #expect(rendered == "Explain black holes to kids. Keep black holes simple.")
    }

    @Test func emptyValuesKeepTheOriginalPlaceholder() {
        let template = PromptTemplate("Translate {{text}} into {{language}}.")
        #expect(template.render(["text": "  ", "language": "French"]) == "Translate {{text}} into French.")
    }

    @Test func dollarVariablesCarryTheirDefault() {
        let template = PromptTemplate("Act as a recruiter at a ${Company Type: Big Company}. Hire a ${Role}.")
        #expect(template.variables.map(\.id) == ["Company Type", "Role"])
        #expect(template.defaultValues["Company Type"] == "Big Company")
        #expect(template.defaultValues["Role"] == "")
    }

    @Test func trailingFirstRequestBecomesAVariable() {
        let template = PromptTemplate(#"I want you to act as a storyteller. My first request is "I need a story about courage.""#)
        #expect(template.variables.count == 1)
        let variable = template.variables.first
        #expect(variable?.id == "first request")
        #expect(variable?.label == "Your first request")
        #expect(variable?.defaultValue == "I need a story about courage.")
        let rendered = template.render(["first request": "Tell me about dragons."])
        #expect(rendered.hasSuffix(#"My first request is "Tell me about dragons.""#))
    }

    @Test func placeholdersSkipTheFirstRequestAndRepeats() {
        let text = #"Use {{tone}} for ${Audience: teens} and {{tone}}. My first request is "Hello.""#
        let placeholders = PromptTemplate.placeholders(in: text)
        #expect(placeholders.map(\.name) == ["tone", "Audience"])
        #expect(placeholders.map(\.token) == ["{{tone}}", "${Audience: teens}"])
    }
}
