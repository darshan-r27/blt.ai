import BLTContentStore
import BLTCore
import BLTDesign
import BLTProgress
import SwiftUI
import UniformTypeIdentifiers

/// Settings has one preference, the language being learned, plus the saved name with Change name,
/// plain statements, and Reset progress.
struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable private var viewModel: SettingsViewModel
    @State private var isChoosingFiles = false

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        let palette = Palette(colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                languageSection(palette: palette)
                section("About the content") {
                    Text(viewModel.contentStatement)
                    if !viewModel.allContentReviewed {
                        Text("\(viewModel.reviewedCount) of \(viewModel.totalCount) reviewed")
                            .font(.headline)
                    }
                }
                if viewModel.canImportLessons {
                    lessonsSection(palette: palette)
                }
                section("Your name") {
                    Text(viewModel.profileName)
                        .font(.headline)
                    Button("Change name") { viewModel.beginChangeName() }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier(AccessibilityID.settingsChangeName)
                }
                section("Privacy") {
                    Text("This app makes no network requests. Your name stays on this device.")
                    Text("Your progress stays on this device.")
                }
                section("Your progress") {
                    Button(role: .destructive, action: { viewModel.requestReset() }, label: {
                        Label("Reset progress", systemImage: "exclamationmark.triangle")
                    })
                        .buttonStyle(.bltWarning)
                        .disabled(viewModel.isResetting)
                        .accessibilityIdentifier(AccessibilityID.settingsReset)
                    resetStatus(palette: palette)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .bltScreenBackground()
        .navigationTitle("Settings")
        .task { await viewModel.refreshImportedSummary() }
        .fileImporter(
            isPresented: $isChoosingFiles,
            allowedContentTypes: [.json],
            allowsMultipleSelection: true
        ) { result in
            Task { await viewModel.importLessons(from: result) }
        }
        .confirmationDialog(
            "Remove imported lessons?",
            isPresented: $viewModel.isConfirmingRemoveImported,
            titleVisibility: .visible
        ) {
            // Not a destructive role: nothing is lost (progress is kept, the files can be imported again),
            // and the system draws that role in red, which this app does not use.
            Button("Remove imported lessons") {
                Task { await viewModel.removeImported() }
            }
            Button("Cancel", role: .cancel) { viewModel.isConfirmingRemoveImported = false }
        } message: {
            Text("The lessons that came with the app are used again. Your progress is kept.")
        }
        .sheet(item: nameEditorBinding) { editor in
            ChangeNameView(viewModel: editor, onCancel: { viewModel.cancelChangeName() })
        }
        .confirmationDialog(
            viewModel.languageChangeTitle,
            isPresented: $viewModel.isConfirmingLanguageChange,
            titleVisibility: .visible
        ) {
            // Not a destructive role: nothing is lost, and the system draws that role in red.
            Button("Switch") {
                Task { await viewModel.confirmLanguageChange() }
            }
            .accessibilityIdentifier(AccessibilityID.settingsLanguageConfirm)
            Button("Cancel", role: .cancel) { viewModel.cancelLanguageChange() }
                .accessibilityIdentifier(AccessibilityID.settingsLanguageCancel)
        } message: {
            Text(viewModel.languageChangeMessage)
        }
        .confirmationDialog(
            viewModel.resetTitle,
            isPresented: $viewModel.isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset progress", role: .destructive) {
                Task { await viewModel.confirmReset() }
            }
            Button("Cancel", role: .cancel) { viewModel.cancelReset() }
        } message: {
            Text(viewModel.resetMessage)
        }
    }

    private func languageSection(palette: Palette) -> some View {
        section("Language I'm learning") {
            Button(action: { viewModel.toggleLanguageChoice() }, label: {
                HStack {
                    Text(viewModel.learningLanguageLabel)
                        .font(.headline)
                    Spacer(minLength: 8)
                    Image(systemName: viewModel.isChoosingLanguage ? "chevron.up" : "chevron.down")
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            })
            .buttonStyle(.bordered)
            .disabled(viewModel.isChangingLanguage)
            .accessibilityLabel("Language I'm learning: \(viewModel.learningLanguageLabel)")
            .accessibilityHint(viewModel.isChoosingLanguage ? "Hides the languages" : "Shows the languages")
            .accessibilityIdentifier(AccessibilityID.settingsLanguage)
            if viewModel.isChoosingLanguage {
                ForEach(viewModel.languageOptions, id: \.self) { language in
                    languageOption(language)
                }
            }
            if viewModel.languageChangeFailed {
                statusText(viewModel.languageChangeFailureMessage, tone: palette.nudge)
            }
        }
    }

    private func languageOption(_ language: CourseLanguage) -> some View {
        let isCurrent = language == viewModel.learningLanguage
        return Button(action: { viewModel.chooseLanguage(language) }, label: {
            Label(language.displayName, systemImage: isCurrent ? "checkmark.circle.fill" : "circle")
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        })
        .buttonStyle(.bordered)
        .accessibilityValue(isCurrent ? "Current language" : "")
        .accessibilityIdentifier(AccessibilityID.settingsLanguageOption(language.rawValue))
    }

    /// Dismissing the sheet by swiping it away counts as Cancel.
    private var nameEditorBinding: Binding<NameEntryViewModel?> {
        Binding(
            get: { viewModel.nameEditor },
            set: { editor in
                if editor == nil { viewModel.cancelChangeName() }
            }
        )
    }

    @ViewBuilder
    private func resetStatus(palette: Palette) -> some View {
        switch viewModel.resetOutcome {
        case .succeeded:
            statusText("Progress was reset.", tone: palette.affirm)
        case .failed:
            statusText("Reset did not finish. Your progress may be unchanged. You can try again.", tone: palette.nudge)
        case nil:
            EmptyView()
        }
    }

    private func lessonsSection(palette: Palette) -> some View {
        section("Lessons") {
            Button("Import lessons") { isChoosingFiles = true }
                .buttonStyle(.bordered)
                .disabled(viewModel.isImporting)
                .accessibilityIdentifier(AccessibilityID.settingsImportLessons)
            Text("Choose lesson files (.json) from the Files app. Your progress is kept.")
            importStatus(palette: palette)
            if let countMessage = viewModel.importedCountMessage {
                Text(countMessage)
                Button("Remove imported lessons", role: .destructive) { viewModel.requestRemoveImported() }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isImporting)
                    .accessibilityIdentifier(AccessibilityID.settingsRemoveImported)
            }
        }
    }

    @ViewBuilder
    private func importStatus(palette: Palette) -> some View {
        if let message = viewModel.importStatusMessage {
            switch viewModel.importOutcome {
            case .succeeded:
                statusText(message, tone: palette.affirm)
                    .accessibilityIdentifier(AccessibilityID.settingsImportStatus)
            case .failed:
                statusText(message, tone: palette.nudge)
                    .accessibilityIdentifier(AccessibilityID.settingsImportStatus)
            case nil:
                EmptyView()
            }
        }
    }

    private func statusText(_ text: String, tone: Palette.TonePair) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(tone.foregroundColor)
            .padding(12)
            .background(tone.backgroundColor, in: RoundedRectangle(cornerRadius: 10))
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        let palette = Palette(colorScheme)
        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(palette.textSecondaryColor)
            content()
                .font(.body)
                .foregroundStyle(palette.textPrimaryColor)
        }
    }
}

#if DEBUG
/// Pretends to import: nothing is read or written. Fake ids only.
private struct PreviewLessonImporter: LessonImporting {
    let active: [ScenarioID]

    func importFiles(_ urls: [URL]) async throws(ContentImportFailure) -> ImportedContentSummary {
        ImportedContentSummary(scenarioIDs: [ScenarioID(rawValue: "zz-imported")])
    }

    func removeAll() async throws(ContentImportFailure) {}

    func currentSummary() async -> ImportedContentSummary {
        ImportedContentSummary(scenarioIDs: active)
    }
}

private struct SettingsPreviewHost: View {
    @State private var viewModel: SettingsViewModel

    init(
        _ dependencies: AppDependencies,
        importer: PreviewLessonImporter? = nil,
        language: CourseLanguage? = nil,
        showingChoice: Bool = false,
        confirming: CourseLanguage? = nil
    ) {
        let model = SettingsViewModel(
            dependencies: dependencies,
            profileStore: InMemoryProfileStore(initial: UserProfile(name: "zz Sample", learningLanguage: language)),
            profileName: "zz Sample",
            lessonImporter: importer,
            learningLanguage: language
        )
        model.isChoosingLanguage = showingChoice
        if let confirming { model.chooseLanguage(confirming) }
        _viewModel = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            SettingsView(viewModel: viewModel)
        }
    }
}

#Preview("Settings, with name") {
    SettingsPreviewHost(PreviewDependencies.withData())
}

#Preview("Settings, with Lessons section") {
    SettingsPreviewHost(
        PreviewDependencies.withData(),
        importer: PreviewLessonImporter(active: [ScenarioID(rawValue: "zz-imported")])
    )
}

#Preview("Settings, dark") {
    SettingsPreviewHost(PreviewDependencies.withData())
        .preferredColorScheme(.dark)
}

#Preview("Settings, largest accessibility size") {
    SettingsPreviewHost(PreviewDependencies.withData())
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Settings, language row") {
    SettingsPreviewHost(PreviewDependencies.withData(), language: .telugu)
}

#Preview("Settings, language not chosen") {
    SettingsPreviewHost(PreviewDependencies.withData())
}

#Preview("Settings, choosing a language, dark") {
    SettingsPreviewHost(PreviewDependencies.withData(), language: .tamil, showingChoice: true)
        .preferredColorScheme(.dark)
}

#Preview("Settings, switch confirmation") {
    SettingsPreviewHost(PreviewDependencies.withData(), language: .tamil, confirming: .telugu)
}

#Preview("Settings, switch confirmation, dark, largest size") {
    SettingsPreviewHost(PreviewDependencies.withData(), language: .tamil, confirming: .telugu)
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Settings, language choice, largest size") {
    SettingsPreviewHost(PreviewDependencies.withData(), language: .telugu, showingChoice: true)
        .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
