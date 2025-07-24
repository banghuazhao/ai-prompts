import SwiftUI

struct PromptEngineeringBestPracticesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                Text("Prompt Engineering Best Practices")
                    .font(AppFont.title)
                    .padding(.bottom, AppSpacing.small)
                Text("Writing effective prompts is key to getting the best results from AI models. Here are some best practices, along with the rules our app uses to analyze your prompts:")
                    .font(AppFont.body)

                Text("Best Practices:")
                    .font(AppFont.headline)
                    .padding(.top, AppSpacing.medium)
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Text("• Be specific: Avoid vague words like 'things' or 'stuff'.")
                    Text("• Add detail: Clarify who, what, how, when, and where if needed.")
                    Text("• Use structure: Break complex tasks into steps or lists.")
                    Text("• Keep it concise: Remove filler and redundant information.")
                    Text("• Specify output: Indicate the desired format (e.g., JSON, list).")
                    Text("• State your audience: Mention if the response should be for beginners, experts, etc.")
                    Text("• Provide examples: Add sample outputs or clarifications.")
                    Text("• Use neutral language: Avoid leading or biased phrases.")
                    Text("• Make your prompt a clear instruction or question.")
                }
                .font(AppFont.body)

                Text("How We Analyze Your Prompts:")
                    .font(AppFont.headline)
                    .padding(.top, AppSpacing.medium)
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Text("• Flags vague or generic wording.")
                    Text("• Checks for missing details in long prompts.")
                    Text("• Suggests adding structure for lengthy instructions.")
                    Text("• Recommends breaking down complex tasks into steps.")
                    Text("• Warns if prompts are too long or contain filler words.")
                    Text("• Detects repeated or redundant sentences.")
                    Text("• Suggests specifying output format and audience.")
                    Text("• Looks for examples in long prompts.")
                    Text("• Encourages clear instructions or questions, especially for short prompts.")
                }
                .font(AppFont.body)

                Text("By following these practices, you can craft prompts that are clear, effective, and more likely to yield the results you want from AI.")
                    .font(AppFont.footnote)
                    .padding(.top, AppSpacing.medium)
            }
            .padding()
        }
        .navigationTitle("Prompt Engineering")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    PromptEngineeringBestPracticesView()
} 