import Dependencies
import SharingGRDB
import SwiftUI
import SwiftUINavigation

@Observable
@MainActor
class VibePromptDetailModel {
    @ObservationIgnored
    @Dependency(\.defaultDatabase) var database

    var vibePrompt: VibePrompt

    @CasePathable
    enum Route {
        case editingPrompt
        case customizing
        case runningOnDevice
        case sharingCard
        case showingDeleteAlert(VibePrompt)
    }

    var route: Route?
    var copiedToClipboard = false

    init(vibePrompt: VibePrompt) {
        self.vibePrompt = vibePrompt
    }

    func onCopy() {
        PromptActions.copy(vibePrompt.prompt)
        copiedToClipboard = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.copiedToClipboard = false
        }
    }

    func onFavorite() {
        withErrorReporting {
            var updatedPrompt = vibePrompt
            updatedPrompt.isFavorite.toggle()
            try database.write { db in
                try VibePrompt.update(updatedPrompt).execute(db)
            }
            vibePrompt = updatedPrompt
            PromptActions.favoriteToggled(isFavorite: updatedPrompt.isFavorite)
        }
    }

    var template: PromptTemplate {
        PromptTemplate(vibePrompt.prompt)
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
        route = .showingDeleteAlert(vibePrompt)
    }

    func confirmDelete(action: () -> Void) {
        withErrorReporting {
            try database.write { db in
                try VibePrompt.delete(vibePrompt).execute(db)
            }
        }
        action()
    }

    func onUpdate(_ newPrompt: VibePrompt) {
        withAnimation {
            route = nil
            vibePrompt = newPrompt
        }
    }
}

struct VibePromptDetailView: View {
    @State var model: VibePromptDetailModel
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

                if "\(model.vibePrompt.app) \(model.vibePrompt.prompt)".looksLikeImagePrompt {
                    CreateImageButton(text: model.vibePrompt.prompt, title: model.vibePrompt.app) {
                        ImagePlaygroundCardLabel()
                    }
                    .buttonStyle(.plain)
                }

                LLMQuickLaunchSection(prompt: model.vibePrompt.prompt)
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
                    colors: [AIStudioPalette.cyan.opacity(0.11), .clear],
                    center: .topTrailing,
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
                .accessibilityLabel("Delete Vibe Prompt")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    ShareLink(item: "\(model.vibePrompt.app)\n\n\(model.vibePrompt.prompt)") {
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
                .accessibilityLabel("Share Vibe Prompt")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Haptics.shared.vibrateIfEnabled()
                    model.onEdit()
                }) {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Edit Vibe Prompt")
            }
        }
        .sheet(isPresented: Binding($model.route.customizing)) {
            PromptCustomizeView(title: model.vibePrompt.app, prompt: model.vibePrompt.prompt)
        }
        .sheet(isPresented: Binding($model.route.runningOnDevice)) {
            PromptRunSheet(title: model.vibePrompt.app, prompt: model.template.runnablePrompt ?? model.vibePrompt.prompt)
        }
        .sheet(isPresented: Binding($model.route.sharingCard)) {
            ShareCardSheet(content: ShareCardContent(title: model.vibePrompt.app, body: model.vibePrompt.prompt))
        }
        .sheet(isPresented: Binding($model.route.editingPrompt)) {
            VibePromptFormView(
                model: VibePromptFormModel(
                    prompt: VibePrompt.Draft(model.vibePrompt)
                ) { newPrompt in
                    model.onUpdate(newPrompt)
                }
            )
        }
        .alert(
            item: $model.route.showingDeleteAlert,
            title: { _ in
                Text("Delete Vibe Prompt")
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
                Text("Are you sure you want to delete \(prompt.app)? This action cannot be undone.")
            }
        )
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                Label("Vibe Prompt", systemImage: "chevron.left.forwardslash.chevron.right")
                    .font(.caption.bold())
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(AIStudioPalette.cyan)

                Spacer(minLength: 12)

                Button(action: model.onFavorite) {
                    Image(systemName: model.vibePrompt.isFavorite ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(.white.opacity(0.16), in: Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.25)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.vibePrompt.isFavorite ? "Remove from Favorites" : "Add to Favorites")
            }

            Text(model.vibePrompt.app)
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            if !model.vibePrompt.contributor.isEmpty {
                Link(destination: model.vibePrompt.contributorGithubURL) {
                    Label(model.vibePrompt.contributor, systemImage: "person.crop.circle")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.16), in: Capsule())
                }
                .tint(.white)
                .accessibilityHint("Opens GitHub profile")
            }

            if !model.vibePrompt.techstack.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tech Stack")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.82))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(model.vibePrompt.techstackArray, id: \.self) { tech in
                                Text(tech)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(.white.opacity(0.16), in: Capsule())
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollClipDisabled()
                }
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

                Image(systemName: "curlybraces")
                    .font(.system(size: 136, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.10))
                    .rotationEffect(.degrees(-12))
                    .offset(x: 30, y: 52)
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

                Text("\(model.vibePrompt.prompt.count) characters")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            TranslatablePromptText(text: model.vibePrompt.prompt)
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
        VibePromptDetailView(
            model: VibePromptDetailModel(
                vibePrompt: VibePrompt(id: 0, app: "Test App", prompt: "This is a test vibe prompt content.", contributor: "Test Contributor", techstack: "Swift, SwiftUI, iOS")
            )
        )
    }
}
