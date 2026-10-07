import BLTProgress
import Foundation
import Observation

/// Drives Settings: the content-review statement, the saved name with Change name, and Reset progress.
/// Reset erases progress only; the name is a different store and is never touched here.
@MainActor
@Observable
public final class SettingsViewModel {
    public enum ResetOutcome: Equatable {
        case succeeded
        case failed(ProgressStoreError)
    }

    public enum ImportOutcome: Equatable {
        /// `count` is the number of imported scenarios now in use.
        case succeeded(count: Int)
        case failed(ContentImportFailure)
    }

    public let reviewedCount: Int
    public let totalCount: Int
    /// True only when the catalog has items and every one is marked `reviewed` (a native Tamil speaker
    /// checked it). The statement below follows the data, so the app never claims more than the content says.
    public var allContentReviewed: Bool { totalCount > 0 && reviewedCount == totalCount }

    /// The "About the content" statement for the current content.
    public var contentStatement: String {
        allContentReviewed
            ? "Every lesson was checked by a native Tamil speaker before it was added to the app."
            : "These lessons were drafted by an AI. Each item shows its review status, "
                + "and an item counts as reviewed only after a native Tamil speaker has checked it."
    }

    public private(set) var resetOutcome: ResetOutcome?
    public private(set) var isResetting = false
    /// The saved display name. Updated as soon as Change name saves.
    public private(set) var profileName: String
    /// Non-nil exactly while the Change name sheet is open.
    public private(set) var nameEditor: NameEntryViewModel?
    /// Bound to the confirmation dialog. Setting it is not a confirmation; only `confirmReset()` erases.
    public var isConfirmingReset = false

    public private(set) var importOutcome: ImportOutcome?
    /// Plain wording for `importOutcome`. Neutral in tone, with no file names or paths.
    public var importStatusMessage: String? {
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
    public var importedCountMessage: String? {
        switch importedCount {
        case 0: nil
        case 1: "1 imported lesson is in use."
        default: "\(importedCount) imported lessons are in use."
        }
    }
    public private(set) var isImporting = false
    /// How many imported scenarios are in use. Refreshed by `refreshImportedSummary()` and after each change.
    public private(set) var importedCount = 0
    /// Bound to the Remove imported lessons dialog. Setting it removes nothing; only `removeImported()` does.
    public var isConfirmingRemoveImported = false
    /// False when the app was composed without an importer (previews, most tests); Settings then hides Lessons.
    public var canImportLessons: Bool { lessonImporter != nil }

    private let store: any ProgressStore
    private let profileStore: any ProfileStore
    private let onDidReset: @MainActor () -> Void
    private let onDidChangeName: @MainActor (UserProfile) -> Void
    private let lessonImporter: (any LessonImporting)?
    private let onDidChangeLessons: @MainActor (LessonChange) -> Void

    /// `onDidReset` lets the owner of Home reload after a successful reset; `onDidChangeName` lets it show
    /// the new name straight away; `onDidChangeLessons` lets the owner of the catalog reload it after an
    /// import or a removal.
    public init(
        dependencies: AppDependencies,
        profileStore: any ProfileStore,
        profileName: String,
        onDidReset: @escaping @MainActor () -> Void = {},
        onDidChangeName: @escaping @MainActor (UserProfile) -> Void = { _ in },
        lessonImporter: (any LessonImporting)? = nil,
        onDidChangeLessons: @escaping @MainActor (LessonChange) -> Void = { _ in }
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
    }

    /// Opens the Change name sheet with the current name in the field. Saves nothing.
    public func beginChangeName() {
        nameEditor = NameEntryViewModel(store: profileStore, initialName: profileName) { [weak self] profile in
            self?.nameDidSave(profile)
        }
    }

    /// Closes the sheet. Whatever was typed is discarded and the saved name is unchanged.
    public func cancelChangeName() {
        nameEditor = nil
    }

    private func nameDidSave(_ profile: UserProfile) {
        profileName = profile.name
        nameEditor = nil
        onDidChangeName(profile)
    }

    /// Step one of Reset: ask the user. Erases nothing.
    public func requestReset() {
        resetOutcome = nil
        isConfirmingReset = true
    }

    public func cancelReset() {
        isConfirmingReset = false
    }

    /// Step two of Reset: wired only to the dialog's destructive button.
    public func confirmReset() async {
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
    public func refreshImportedSummary() async {
        guard let lessonImporter else { return }
        importedCount = await lessonImporter.currentSummary().count
    }

    /// Handles the Files picker's result. A cancelled picker is not an error and changes nothing.
    /// Success is all or nothing, so on any failure the lessons are exactly as they were.
    public func importLessons(from result: Result<[URL], any Error>) async {
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
    public func requestRemoveImported() {
        importOutcome = nil
        isConfirmingRemoveImported = true
    }

    /// Step two: wired only to the dialog's button. The bundled lessons are used again afterwards.
    public func removeImported() async {
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
