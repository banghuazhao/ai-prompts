import Dependencies
import SwiftUI
import SwiftUINavigation
import SharingGRDB

@Observable
@MainActor
class PromptDetailModel {
    @ObservationIgnored
    @Dependency(\.defaultDatabase) var database

    var prompt: Prompt

    @CasePathable
    enum Route {
        case editingPrompt
        case customizing
        case runningOnDevice
        case sharingCard
        case showingDeleteAlert(Prompt)
    }

    var route: Route?

    var copiedToClipboard = false

    init(prompt: Prompt) {
        self.prompt = prompt
    }
    
    var category: PromptCategory? {
        try? database.read { db in
            try? PromptCategory
                .all
                .where { $0.id.is(prompt.categoryID) }
                .fetchOne(db)
        }
    }

    func onCopy() {
        PromptActions.copy(prompt.prompt)
        copiedToClipboard = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.copiedToClipboard = false
        }
    }

    func onFavorite() {
        withErrorReporting {
            var updatedPrompt = prompt
            updatedPrompt.isFavorite.toggle()
            try database.write { db in
                try Prompt.update(updatedPrompt).execute(db)
            }
            prompt = updatedPrompt
            PromptActions.favoriteToggled(isFavorite: updatedPrompt.isFavorite)
        }
    }

    var template: PromptTemplate {
        PromptTemplate(prompt.prompt)
    }

    func onCustomize() {
        route = .customizing
    }

    /// Runs the prompt right away when every blank has a value, otherwise asks for them first.
    func onRunOnDevice() {
        route = template.runnablePrompt == nil ? .customizing : .runningOnDevice
    }

    func onEdit() {
        route = .editingPrompt
    }

    func onDeleteRequest() {
        route = .showingDeleteAlert(prompt)
    }

    func confirmDelete(action: () -> Void) {
        withErrorReporting {
            try database.write { db in
                try Prompt.delete(prompt).execute(db)
            }
        }
        action()
    }

    func onUpdate(_ newPrompt: Prompt) {
        withAnimation {
            route = nil
            prompt = newPrompt
        }
    }
}

struct PromptDetailView: View {
    @State var model: PromptDetailModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                promptCard

                let template = model.template
                if template.hasVariables {
                    PromptCustomizeCard(variableCount: template.variables.count) {
                        model.onCustomize()
                    }
                }

                if OnDeviceAI.isSupported {
                    RunOnDeviceCard {
                        model.onRunOnDevice()
                    }
                }

                if "\(model.prompt.act) \(model.prompt.prompt)".looksLikeImagePrompt {
                    CreateImageButton(text: model.prompt.prompt, title: model.prompt.act) {
                        ImagePlaygroundCardLabel()
                    }
                    .buttonStyle(.plain)
                }

                LLMQuickLaunchSection(prompt: model.prompt.prompt)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background {
            ZStack {
                AIStudioPalette.canvas
                RadialGradient(
                    colors: [AIStudioPalette.violet.opacity(0.12), .clear],
                    center: .topLeading,
                    startRadius: 12,
                    endRadius: 480
                )
            }
            .ignoresSafeArea()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Haptics.shared.vibrateIfEnabled()
                    model.onDeleteRequest()
                }) {
                    Image(systemName: "trash")
                }
                .tint(.red)
                .accessibilityLabel("Delete Prompt")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    ShareLink(item: "\(model.prompt.act)\n\n\(model.prompt.prompt)") {
                        Label("Share Text", systemImage: "text.alignleft")
                    }
                    .simultaneousGesture(TapGesture().onEnded { PromptActions.share() })
                    Button("Share as Image", systemImage: "photo") {
                        Haptics.shared.vibrateIfEnabled()
                        model.route = .sharingCard
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share Prompt")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Haptics.shared.vibrateIfEnabled()
                    model.onEdit()
                }) {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Edit Prompt")
            }
        }
        .sheet(isPresented: Binding($model.route.customizing)) {
            PromptCustomizeView(title: model.prompt.act, prompt: model.prompt.prompt)
        }
        .sheet(isPresented: Binding($model.route.runningOnDevice)) {
            PromptRunSheet(title: model.prompt.act, prompt: model.template.runnablePrompt ?? model.prompt.prompt)
        }
        .sheet(isPresented: Binding($model.route.sharingCard)) {
            ShareCardSheet(content: ShareCardContent(title: model.prompt.act, body: model.prompt.prompt))
        }
        .sheet(isPresented: Binding($model.route.editingPrompt)) {
            PromptFormView(
                model: PromptFormModel(
                    prompt: Prompt.Draft(model.prompt)
                ) { newPrompt in
                    model.onUpdate(newPrompt)
                }
            )
        }
        .alert(
            item: $model.route.showingDeleteAlert,
            title: { _ in
                Text("Delete Prompt")
            },
            actions: { _ in
                Button("Delete", role: .destructive) {
                    Haptics.shared.vibrateIfEnabled()
                    model.confirmDelete {
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {
                    Haptics.shared.vibrateIfEnabled()
                }
            },
            message: { prompt in
                Text("Are you sure you want to delete \(prompt.act)? This action cannot be undone.")
            }
        )
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                Label("AI Prompt", systemImage: "sparkles")
                    .font(.caption.bold())
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(AIStudioPalette.cyan)

                Spacer(minLength: 12)

                Button(action: model.onFavorite) {
                    Image(systemName: model.prompt.isFavorite ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(.white.opacity(0.16), in: Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.25)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.prompt.isFavorite ? "Remove from Favorites" : "Add to Favorites")
            }

            Text(model.prompt.act)
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            if let category = model.category {
                Label(Bundle.main.localizedString(forKey: category.title, value: category.title, table: nil), systemImage: "square.grid.2x2.fill")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.16), in: Capsule())
            }

            if model.prompt.forDevs {
                Label("For Developers", systemImage: "chevron.left.forwardslash.chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.16), in: Capsule())
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 28)
                    .fill(AIStudioPalette.heroGradient)

                Circle()
                    .fill(AIStudioPalette.cyan.opacity(0.22))
                    .frame(width: 160, height: 160)
                    .blur(radius: 36)
                    .offset(x: 55, y: -55)
                    .accessibilityHidden(true)

                Image(systemName: "sparkles")
                    .font(.system(size: 118, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.10))
                    .rotationEffect(.degrees(-16))
                    .offset(x: 20, y: 60)
                    .accessibilityHidden(true)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28))
        }
        .shadow(color: AIStudioPalette.violet.opacity(0.20), radius: 20, x: 0, y: 10)
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Label("Prompt", systemImage: "text.alignleft")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer(minLength: 12)

                Text("\(model.prompt.prompt.count) characters")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            TranslatablePromptText(text: model.prompt.prompt)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                Haptics.shared.vibrateIfEnabled()
                model.onCopy()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: model.copiedToClipboard ? "checkmark" : "doc.on.doc")
                    Text(model.copiedToClipboard ? "Copied!" : "Copy Prompt")
                    Spacer(minLength: 8)
                    Image(systemName: model.copiedToClipboard ? "checkmark.circle.fill" : "arrow.right")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(minHeight: 54)
                .background(AIStudioPalette.heroGradient, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(model.copiedToClipboard)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AIStudioPalette.surface, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(AIStudioPalette.border))
        .shadow(color: AIStudioPalette.ink.opacity(0.06), radius: 18, x: 0, y: 8)
    }
}

#Preview {
    NavigationStack {
        PromptDetailView(
            model: PromptDetailModel(
                prompt: Prompt(id: 1, act: "Test Prompt", prompt: "This is a test prompt content.", forDevs: true)
            )
        )
    }
}
