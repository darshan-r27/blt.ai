import BLTContentStore
import BLTCore
import BLTProgress
import Foundation
import Observation

/// Drives Settings: the content-review statement, the saved name with Change name, and Reset progress.
/// Reset erases progress only; the name is a different store and is never touched here.
@MainActor
@Observable
final class SettingsViewModel {
    enum ResetOutcome: Equatable {
        case succeeded
        case failed(ProgressStoreError)
    }

    enum ImportOutcome: Equatable {
        /// `count` is the number of imported scenarios now in use.
        case succeeded(count: Int)
        case failed(ContentImportFailure)
    }

    let reviewedCount: Int
    let totalCount: Int
    /// True only when the catalog has items and every one is marked `reviewed` (a native Tamil / Telugu speaker
    /// checked it). The statement below follows the data, so the app never claims more than the content says.
    var allContentReviewed: Bool { totalCount > 0 && reviewedCount == totalCount }

    /// The "About the content" statement for the current content. It names the language being learned when
    /// the owner of Settings supplied one; with none it keeps the original "Tamil / Telugu" wording.
    var contentStatement: String {
        let speaker = learningLanguage.map { "native \($0.displayName) speaker" } ?? "native Tamil / Telugu speaker"
        return allContentReviewed
            ? "Every lesson was checked by a \(speaker) before it was added to the app."
            : "These lessons were drafted by an AI. Each item shows its review status, "
                + "and an item counts as reviewed only after a \(speaker) has checked it."
    }

    /// The language being learned, or `nil` when none was supplied or chosen. Updated when a switch is saved.
    private(set) var learningLanguage: CourseLanguage?
    /// The current language's name for the Settings row, or a neutral "Not chosen".
    var learningLanguageLabel: String { learningLanguage?.displayName ?? "Not chosen" }
    /// Both languages, in a fixed order, for the choice under the row.
    var languageOptions: [CourseLanguage] { CourseLanguage.allCases }
    /// True while the two languages are shown under the row. Showing them changes nothing.
    var isChoosingLanguage = false
    /// The language the learner picked and has not yet confirmed. Non-nil exactly while the confirmation shows.
    private(set) var pendingLanguage: CourseLanguage?
    /// True after a switch could not be saved. Nothing was changed. Cleared by the next attempt.
    private(set) var languageChangeFailed = false
    private(set) var isChangingLanguage = false
    /// Bound to the Switch confirmation. Setting it to false is a cancel; only `confirmLanguageChange()` saves.
    var isConfirmingLanguageChange: Bool {
        get { pendingLanguage != nil }
        set { if !newValue { cancelLanguageChange() } }
    }
    var languageChangeTitle: String {
        pendingLanguage.map { "Switch to \($0.displayName)?" } ?? "Switch language?"
    }
    var languageChangeMessage: String {
        "Each language keeps its own progress, so nothing is lost. You can switch back any time."
    }
    var languageChangeFailureMessage: String {
        "The language could not be changed, so nothing was changed. You can try again."
    }

    /// Title of the Reset confirmation. Names the language when one is known.
    var resetTitle: String {
        learningLanguage.map { "Reset \($0.displayName) progress?" } ?? "Reset all progress?"
    }
    /// Message of the Reset confirmation. Says which language it clears when one is known.
    var resetMessage: String {
        if let learningLanguage {
            return "This clears your \(learningLanguage.displayName) progress. "
                + "Your name and your other language's progress are kept. It cannot be undone."
        }
        return "This erases your review schedule and answer history on this device. "
            + "It cannot be undone. Your name is not erased."
    }

    private(set) var resetOutcome: ResetOutcome?
    private(set) var isResetting = false
    /// The saved display name. Updated as soon as Change name saves.
    private(set) var profileName: String
    /// Non-nil exactly while the Change name sheet is open.
    private(set) var nameEditor: NameEntryViewModel?
    /// Bound to the confirmation dialog. Setting it is not a confirmation; only `confirmReset()` erases.
    var isConfirmingReset = false

    private(set) var importOutcome: ImportOutcome?
    /// Plain wording for `importOutcome`. Neutral in tone, with no file names or paths.
    var importStatusMessage: String? {
        switch importOutcome {
        case .succeeded:
            return "Lessons imported. Your progress is kept."
        case .failed(.noFiles):
            return "No file was chosen."
        case .failed(.tooManyFiles(let limit)):
            return "Choose up to \(limit) files at a time."
        case .failed(.unreadable):
            return "A file could not be read. If it is in iCloud Drive, download it first."
        case .failed(.invalid(let issueCount)):
            let problems = issueCount == 1 ? "1 problem" : "\(issueCount) problems"
            return "Nothing was imported: the file did not pass the lesson checks (\(problems)). "
                + "Your lessons are unchanged."
        case .failed(.couldNotSave):
            return "The lessons could not be saved. Your lessons are unchanged."
        case nil:
            return nil
        }
    }
    /// The count line under Import lessons, or `nil` when nothing is imported.
    var importedCountMessage: String? {
        switch importedCount {
        case 0: nil
        case 1: "1 imported lesson is in use."
        default: "\(importedCount) imported lessons are in use."
        }
    }
    private(set) var isImporting = false
    /// How many imported scenarios are in use. Refreshed by `refreshImportedSummary()` and after each change.
    private(set) var importedCount = 0
    /// Bound to the Remove imported lessons dialog. Setting it removes nothing; only `removeImported()` does.
    var isConfirmingRemoveImported = false
    /// False when the app was composed without an importer (previews, most tests); Settings then hides Lessons.
    var canImportLessons: Bool { lessonImporter != nil }

    private let store: any ProgressStore
    private let profileStore: any ProfileStore
    private let onDidReset: @MainActor () -> Void
    private let onDidChangeName: @MainActor (UserProfile) -> Void
    private let lessonImporter: (any LessonImporting)?
    private let onDidChangeLessons: @MainActor (LessonChange) -> Void
    private let onDidChangeLanguage: @MainActor (UserProfile) -> Void

    /// `onDidReset` lets the owner of Home reload after a successful reset; `onDidChangeName` lets it show
    /// the new name straight away; `onDidChangeLessons` lets the owner of the catalog reload it after an
    /// import or a removal; `onDidChangeLanguage` lets it rebuild the root for the other course after a switch
    /// is saved. `learningLanguage` is `nil` ("absent") unless the owner passes one: Settings never assumes one.
    init(
        dependencies: AppDependencies,
        profileStore: any ProfileStore,
        profileName: String,
        onDidReset: @escaping @MainActor () -> Void = {},
        onDidChangeName: @escaping @MainActor (UserProfile) -> Void = { _ in },
        lessonImporter: (any LessonImporting)? = nil,
        onDidChangeLessons: @escaping @MainActor (LessonChange) -> Void = { _ in },
        learningLanguage: CourseLanguage? = nil,
        onDidChangeLanguage: @escaping @MainActor (UserProfile) -> Void = { _ in }
    ) {
        reviewedCount = dependencies.catalog.reviewedItemCount
        totalCount = dependencies.catalog.totalItemCount
        store = dependencies.store
        self.profileStore = profileStore
        self.profileName = profileName
        self.onDidReset = onDidReset
        self.onDidChangeName = onDidChangeName
        self.lessonImporter = lessonImporter
        self.onDidChangeLessons = onDidChangeLessons
        self.learningLanguage = learningLanguage
        self.onDidChangeLanguage = onDidChangeLanguage
    }

    // MARK: Language

    /// Shows or hides the two languages under the row. Saves nothing.
    func toggleLanguageChoice() {
        isChoosingLanguage.toggle()
    }

    /// The learner picked a language. The current language does nothing; the other one asks first.
    func chooseLanguage(_ language: CourseLanguage) {
        isChoosingLanguage = false
        guard language != learningLanguage else { return }
        languageChangeFailed = false
        pendingLanguage = language
    }

    /// Closes the confirmation. Nothing is saved and the language is unchanged.
    func cancelLanguageChange() {
        pendingLanguage = nil
    }

    /// Wired only to the confirmation's Switch button. Writes the stored profile with the new language and
    /// the same name, then tells the owner. On any failure nothing changes and the owner is not told.
    func confirmLanguageChange() async {
        guard let language = pendingLanguage, !isChangingLanguage else { return }
        pendingLanguage = nil
        isChangingLanguage = true
        defer { isChangingLanguage = false }
        languageChangeFailed = false
        let updated: UserProfile
        do throws(ProfileStoreError) {
            // A missing stored profile cannot be updated: report it rather than inventing a name.
            guard let stored = try await profileStore.load() else {
                languageChangeFailed = true
                return
            }
            updated = stored.withLearningLanguage(language)
            try await profileStore.save(updated)
        } catch {
            languageChangeFailed = true
            return
        }
        learningLanguage = language
        onDidChangeLanguage(updated)
    }

    /// Opens the Change name sheet with the current name in the field. Saves nothing.
    func beginChangeName() {
        nameEditor = NameEntryViewModel(store: profileStore, initialName: profileName) { [weak self] profile in
            self?.nameDidSave(profile)
        }
    }

    /// Closes the sheet. Whatever was typed is discarded and the saved name is unchanged.
    func cancelChangeName() {
        nameEditor = nil
    }

    private func nameDidSave(_ profile: UserProfile) {
        profileName = profile.name
        nameEditor = nil
        onDidChangeName(profile)
    }

    /// Step one of Reset: ask the user. Erases nothing.
    func requestReset() {
        resetOutcome = nil
        isConfirmingReset = true
    }

    func cancelReset() {
        isConfirmingReset = false
    }

    /// Step two of Reset: wired only to the dialog's destructive button.
    func confirmReset() async {
        isConfirmingReset = false
        guard !isResetting else { return }
        isResetting = true
        defer { isResetting = false }
        do throws(ProgressStoreError) {
            try await store.eraseAll()
        } catch {
            resetOutcome = .failed(error)
            return
        }
        resetOutcome = .succeeded
        onDidReset()
    }

    // MARK: Lessons

    /// Reads how many imported scenarios are in use, for the Lessons section.
    func refreshImportedSummary() async {
        guard let lessonImporter else { return }
        importedCount = await lessonImporter.currentSummary().count
    }

    /// Handles the Files picker's result. A cancelled picker is not an error and changes nothing.
    /// Success is all or nothing, so on any failure the lessons are exactly as they were.
    func importLessons(from result: Result<[URL], any Error>) async {
        guard let lessonImporter, !isImporting else { return }
        let urls: [URL]
        switch result {
        case .success(let chosen):
            urls = chosen
        case .failure(let error):
            if Self.isCancellation(error) { return }
            importOutcome = .failed(.unreadable)
            return
        }
        importOutcome = nil
        isImporting = true
        defer { isImporting = false }
        do throws(ContentImportFailure) {
            let summary = try await lessonImporter.importFiles(urls)
            importedCount = summary.count
            importOutcome = .succeeded(count: summary.count)
            onDidChangeLessons(.imported(scenarioCount: summary.count))
        } catch {
            importOutcome = .failed(error)
        }
    }

    /// Step one of Remove imported lessons: ask the user. Removes nothing.
    func requestRemoveImported() {
        importOutcome = nil
        isConfirmingRemoveImported = true
    }

    /// Step two: wired only to the dialog's button. The bundled lessons are used again afterwards.
    func removeImported() async {
        isConfirmingRemoveImported = false
        guard let lessonImporter, !isImporting else { return }
        isImporting = true
        defer { isImporting = false }
        do throws(ContentImportFailure) {
            try await lessonImporter.removeAll()
        } catch {
            importOutcome = .failed(error)
            // A removal that failed part-way may have taken some files, so read the real figure again.
            importedCount = await lessonImporter.currentSummary().count
            return
        }
        importedCount = 0
        importOutcome = nil
        onDidChangeLessons(.removed)
    }

    private static func isCancellation(_ error: any Error) -> Bool {
        (error as? CocoaError)?.code == .userCancelled
    }
}
