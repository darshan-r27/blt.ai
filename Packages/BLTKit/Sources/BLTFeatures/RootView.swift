import BLTCatalog
import BLTCore
import BLTDesign
import BLTProgress
import SwiftUI

/// The app's front door and navigation.
///
/// It first loads the saved profile (DECISIONS 030). With none, the person sees the intro, name entry and the
/// language step once; a profile saved before the language existed is asked for a language (DECISIONS 043);
/// with both, Home opens straight away; a profile that cannot be read gets a calm explanation instead of
/// being silently replaced. Home then works as before: Scenarios is home, Progress and Settings push onto
/// its stack, and a session covers the whole screen.
///
/// The learner's language is only known once the profile has loaded, so the root does not take one fixed
/// `AppDependencies`. It takes `makeCourse`, which the composition root answers per language, and builds
/// Home only for the language on the profile. Home is given the language as its identity, so switching
/// language in Settings rebuilds Home and every view model under it on the other course.
public struct RootView: View {
    private let profileStore: any ProfileStore
    private let onLessonsChanged: @MainActor (LessonChange) -> Void
    private let practice: PracticeServices
    @State private var courses: CourseCache
    @State private var gate: ProfileGateViewModel

    /// `makeCourse` builds the dependencies and the lesson importer for one language; it is called at most
    /// once per language for the life of this view. `practice` holds the device-wide daily-practice pieces
    /// (reminders, their choices, the way to iOS Settings; DECISIONS 047). After an import or a removal, `onLessonsChanged` tells the
    /// owner of the catalog to build a new root, which asks `makeCourse` again for the current language.
    public init(
        profileStore: any ProfileStore,
        makeCourse: @escaping @MainActor (CourseLanguage) -> CourseServices,
        practice: PracticeServices = PracticeServices(),
        onLessonsChanged: @escaping @MainActor (LessonChange) -> Void = { _ in }
    ) {
        self.profileStore = profileStore
        self.practice = practice
        self.onLessonsChanged = onLessonsChanged
        _courses = State(initialValue: CourseCache(make: makeCourse))
        _gate = State(initialValue: ProfileGateViewModel(store: profileStore))
    }

    public var body: some View {
        content
            // Once, at the root: the purple accent reaches toolbar icons, links, cursors, sheets and the session cover.
            .bltTheme()
            .task { await gate.load() }
    }

    @ViewBuilder private var content: some View {
        switch gate.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .bltScreenBackground()
        case .needsOnboarding:
            OnboardingFlow(gate: gate)
        case .needsLanguage(let profile):
            LanguageChoiceView(gate: gate, profile: profile)
        case .loadFailed(let error):
            ProfileLoadProblemView(gate: gate, error: error)
        case .ready(let profile):
            ready(profile)
        }
    }

    @ViewBuilder private func ready(_ profile: UserProfile) -> some View {
        if let language = profile.learningLanguage {
            let course = courses.services(for: language)
            HomeFlow(
                dependencies: course.dependencies,
                profileStore: profileStore,
                name: profile.name,
                onNameChanged: { gate.profileDidChange($0) },
                onLanguageChanged: { gate.profileDidChange($0) },
                lessonImporter: course.lessonImporter,
                onLessonsChanged: onLessonsChanged,
                practice: practice
            )
            // A different language is a different course: new catalog, new progress, new view models.
            .id(language)
        } else {
            // The gate never reports `.ready` without a language; if it ever did, ask rather than assume one.
            LanguageChoiceView(gate: gate, profile: profile)
        }
    }
}

/// Builds each language's `CourseServices` on first use and keeps it, so a redraw of the root never loads a
/// catalog twice. Lives as long as one `RootView`; a new root (after a lesson import) starts empty.
@MainActor
private final class CourseCache {
    private let make: @MainActor (CourseLanguage) -> CourseServices
    private var built: [CourseLanguage: CourseServices] = [:]

    init(make: @escaping @MainActor (CourseLanguage) -> CourseServices) {
        self.make = make
    }

    func services(for language: CourseLanguage) -> CourseServices {
        if let existing = built[language] { return existing }
        let services = make(language)
        built[language] = services
        return services
    }
}

/// Owns the Progress view model so it lives as long as the pushed screen does.
struct ProgressDestination: View {
    @State private var viewModel: ProgressViewModel

    init(dependencies: AppDependencies) {
        _viewModel = State(initialValue: ProgressViewModel(dependencies: dependencies))
    }

    var body: some View {
        ProgressScreen(viewModel: viewModel)
    }
}

/// Owns the Settings view model, so a fresh visit starts without the last visit's reset message.
struct SettingsDestination: View {
    @State private var viewModel: SettingsViewModel

    init(
        dependencies: AppDependencies,
        profileStore: any ProfileStore,
        name: String,
        onDidReset: @escaping @MainActor () -> Void,
        onDidChangeName: @escaping @MainActor (UserProfile) -> Void,
        onDidChangeLanguage: @escaping @MainActor (UserProfile) -> Void,
        lessonImporter: (any LessonImporting)?,
        onDidChangeLessons: @escaping @MainActor (LessonChange) -> Void,
        practice: PracticeServices,
        onPracticeSettingsChanged: @escaping @Sendable () async -> Void
    ) {
        _viewModel = State(initialValue: SettingsViewModel(
            dependencies: dependencies,
            profileStore: profileStore,
            profileName: name,
            onDidReset: onDidReset,
            onDidChangeName: onDidChangeName,
            lessonImporter: lessonImporter,
            onDidChangeLessons: onDidChangeLessons,
            learningLanguage: dependencies.language,
            onDidChangeLanguage: onDidChangeLanguage,
            practicePreferences: practice.preferences,
            practiceLog: dependencies.practiceLog,
            reminders: practice.reminders,
            onPracticeSettingsChanged: onPracticeSettingsChanged,
            openSystemSettings: practice.openSystemSettings
        ))
    }

    var body: some View {
        SettingsView(viewModel: viewModel)
    }
}

#if DEBUG
#Preview("Root, first launch") {
    RootView(profileStore: InMemoryProfileStore(), makeCourse: PreviewCourses.make)
}

#Preview("Root, saved name and language") {
    RootView(
        profileStore: InMemoryProfileStore(initial: UserProfile(name: "zz Sample", learningLanguage: .tamil)),
        makeCourse: PreviewCourses.make
    )
}

#Preview("Root, saved name, no language") {
    RootView(
        profileStore: InMemoryProfileStore(initial: UserProfile(name: "zz Sample")),
        makeCourse: PreviewCourses.make
    )
}
#endif
