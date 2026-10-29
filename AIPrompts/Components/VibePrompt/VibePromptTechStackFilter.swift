import SwiftUI
import SwiftUINavigation

import SwiftUIFlowLayout

struct VibePromptTechStackFilter: View {
    @Bindable var model: VibePromptListModel

    var body: some View {
        NavigationStack {
            ScrollView {
                FlowLayout(items: model.allTechStacks) { techStack in
                    Button(action: {
                        Haptics.shared.vibrateIfEnabled()
                        model.onSelectTechStack(techStack)
                    }) {
                        HStack(spacing: 4) {
                            Text(techStack)
                                .font(.callout)
                                .foregroundColor(.primary)
                            if model.selectedTechStacks.contains(techStack) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AIStudioPalette.violet)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .glassCapsule(
                            tint: model.selectedTechStacks.contains(techStack) ? AIStudioPalette.violet.opacity(0.25) : nil,
                            interactive: true,
                            fallback: model.selectedTechStacks.contains(techStack) ? AIStudioPalette.violet.opacity(0.15) : AIStudioPalette.surface
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .navigationTitle("Filter by Tech Stack")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}
