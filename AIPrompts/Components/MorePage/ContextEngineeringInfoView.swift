import SwiftUI

struct ContextEngineeringInfoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                Text("Context Engineering")
                    .font(AppFont.title)
                    .padding(.bottom, AppSpacing.small)
                Text("Context engineering is the art and science of providing just the right information to an AI model for the best results. It goes beyond simple prompt writing—focusing on how to structure, prune, and optimize all the information (context) you give to the model. By applying context engineering, you can make your prompts clearer, more effective, and more efficient.")
                    .font(AppFont.body)
                Text("Key Principles:")
                    .font(AppFont.headline)
                    .padding(.top, AppSpacing.medium)
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Text("• Start with the fundamental context needed for the task.")
                    Text("• Add only what the model demonstrably lacks.")
                    Text("• Prune irrelevant or redundant information.")
                    Text("• Use structure (lists, JSON, etc.) for clarity.")
                    Text("• Break complex tasks into steps.")
                }
                .font(AppFont.body)
                Text("Learn more: [Context-Engineering Handbook](https://github.com/davidkimai/Context-Engineering)")
                    .font(AppFont.footnote)
                    .foregroundColor(.blue)
                    .padding(.top, AppSpacing.medium)
            }
            .padding()
        }
        .navigationTitle("Context Engineering")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ContextEngineeringInfoView()
} 