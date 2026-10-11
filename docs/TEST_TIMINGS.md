# UI test timings (measured before the two-tier reshape)

Measured for DECISIONS 045 / plan.md chunk Q1, on 2026-10-09, **before** any test was moved, so every cut below
follows from these numbers. Source: the step logs of ten completed CI runs of `Package and app tests` on the
`xcode-27` preview runner (`gh run view <id> --log`, the xcodebuild `Test case '...' passed|failed on ... (N seconds)`
lines). No secrets are in these logs. The runs, newest first:

| Run | Event, branch | Whole job | Package tests | App build + UI tests |
|---|---|---:|---:|---:|
| 38013032062 | pull request, handoff-wave1 | 29 min | 7.6 min | 21.4 min |
| 38012870767 | push, main | 33 min | 6.3 min | 26.7 min |
| 38009307756 | push, main | 35 min | 6.7 min | 28.2 min |
| 38008535771 | pull request, c1-catalog-format | 60 min | 7.9 min | 51.9 min |
| 38007914100 | pull request, c2-editor-fields | 40 min | 4.7 min | 35.3 min |
| 38007663438 | pull request, c3-content-index | 21 min | 4.1 min | 16.5 min |
| 38003843290 | pull request, content-s05-reviewed | 53 min | 7.2 min | 45.8 min |
| 38003796968 | pull request, content-all-reviewed | 45 min | 6.4 min | 38.5 min |
| 38003467818 | pull request, course-plan | 30 min | 6.9 min | 22.8 min |
| 37713315092 | push, main | 33 min | 5.9 min | 26.8 min |

**Headlines**

- The whole `Package and app tests` job took 21 to 60 minutes, median about 34. The UI step is 16.5 to 52
  minutes, median 27.5, and is 80 percent or more of every run. Package tests are 4 to 8 minutes and include a
  build of the packages.
- 50 UI tests; the sum of their mean durations is 1821 seconds (30 minutes of test time), run on two parallel
  simulator clones (xcodebuild splits by class: `AccessibilityUITests` on one clone, the rest on the other).
- A single test took 14 to 72 seconds on average and up to 220 seconds when it passed. The slowest passing run
  of any kept test was 162 seconds (`testChangeNameSheetAuditAtXXXL`).
- **Retries: 6 failed attempts in 10 runs, in 6 different tests, each passing on the next try.** Three of the six
  attempts took 251, 788 and 889 seconds before failing: the preview runner's hung UI query. Those three are
  how a 20-minute run turns into a 45 or 60 minute one. A per-test time limit does not fix that: tried locally with
  `-test-timeouts-enabled` at 240 seconds, a hung `testHomeAudit` was failed at exactly 240 seconds and was **not**
  retried (the result bundle shows one failed attempt; a test that fails normally shows three), so a limit would turn
  a hang that passes on retry into a failed job. It is available as the opt-in `BLT_TEST_TIMEOUT`, off by default.
  Fewer tests per pull request is the lever that is left (13 instead of 50).
- Accessibility tests are 21 of the 50 tests and 577 of the 1821 seconds; the largest-size part of them
  (13 tests, 363 seconds) moves to the full tier. None is deleted.

**Per-test table** (mean and slowest are over the runs where the test passed; "Failed attempts" counts attempts
that failed and were retried, over all ten runs; every test was seen in all ten runs).

| Test | Class | Mean s | Slowest s | Failed attempts | Runs seen | Decision |
|---|---|---:|---:|---:|---:|---|
| testChangeNameSheetAudit | AccessibilityUITests | 45 | 77 | 0 | 10 | kept, PR tier |
| testChangeNameSheetAuditAtXXXL | AccessibilityUITests | 56 | 162 | 1 | 10 | kept, full tier (moved to AccessibilityLargeTextUITests) |
| testChangeNameSheetControlsAreReachableAtXXXL | AccessibilityUITests | 40 | 95 | 0 | 10 | kept, full tier (moved to AccessibilityLargeTextUITests) |
| testFeedbackAudit | AccessibilityUITests | 25 | 39 | 0 | 10 | kept, PR tier |
| testFeedbackAuditAtXXXL | AccessibilityUITests | 25 | 35 | 0 | 10 | kept, full tier (moved to AccessibilityLargeTextUITests) |
| testHomeAudit | AccessibilityUITests | 20 | 33 | 0 | 10 | kept, PR tier |
| testHomeAuditAtXXXL | AccessibilityUITests | 14 | 21 | 0 | 10 | kept, full tier (moved to AccessibilityLargeTextUITests) |
| testHomeControlsAreReachableAtXXXL | AccessibilityUITests | 16 | 27 | 0 | 10 | kept, full tier (moved to AccessibilityLargeTextUITests) |
| testIntroAndNameEntryControlsAreReachableAtXXXL | AccessibilityUITests | 24 | 55 | 0 | 10 | kept, full tier (moved to AccessibilityLargeTextUITests) |
| testIntroAudit | AccessibilityUITests | 15 | 30 | 0 | 10 | kept, PR tier |
| testIntroAuditAtXXXL | AccessibilityUITests | 15 | 25 | 0 | 10 | kept, full tier (moved to AccessibilityLargeTextUITests) |
| testNameEntryAudit | AccessibilityUITests | 36 | 147 | 0 | 10 | kept, PR tier |
| testNameEntryAuditAtXXXL | AccessibilityUITests | 35 | 123 | 0 | 10 | kept, full tier (moved to AccessibilityLargeTextUITests) |
| testProgressAudit | AccessibilityUITests | 25 | 42 | 0 | 10 | kept, PR tier |
| testProgressAuditAtXXXL | AccessibilityUITests | 23 | 34 | 0 | 10 | kept, full tier (moved to AccessibilityLargeTextUITests) |
| testQuestionAudit | AccessibilityUITests | 24 | 51 | 0 | 10 | kept, PR tier |
| testQuestionAuditAtXXXL | AccessibilityUITests | 22 | 34 | 0 | 10 | kept, full tier (moved to AccessibilityLargeTextUITests) |
| testSessionControlsAreReachableAtXXXL | AccessibilityUITests | 29 | 58 | 0 | 10 | kept, full tier (moved to AccessibilityLargeTextUITests) |
| testSettingsAudit | AccessibilityUITests | 24 | 33 | 1 | 10 | kept, PR tier |
| testSettingsAuditAtXXXL | AccessibilityUITests | 22 | 33 | 0 | 10 | kept, full tier (moved to AccessibilityLargeTextUITests) |
| testSettingsControlsAreReachableAtXXXL | AccessibilityUITests | 42 | 77 | 0 | 10 | kept, full tier (moved to AccessibilityLargeTextUITests) |
| testAnswerGivenBeforeEndingIsCounted | EndSessionUITests | 47 | 118 | 1 | 10 | removed; rule now in the package |
| testConfirmingEndReturnsHome | EndSessionUITests | 42 | 147 | 0 | 10 | kept, PR tier (moved to HappyPathUITests) |
| testEndControlIsVisibleOnQuestionAndFeedback | EndSessionUITests | 27 | 39 | 1 | 10 | kept, full tier |
| testEndControlShowsConfirmation | EndSessionUITests | 19 | 31 | 0 | 10 | kept, full tier |
| testKeepGoingResumesTheSameQuestion | EndSessionUITests | 26 | 42 | 0 | 10 | kept, full tier |
| testCanonicalOptionReachesCorrectFeedback | FeedbackFlowUITests | 60 | 171 | 1 | 10 | removed; rule now in the package |
| testFinishedSummaryAppearsAfterLastItemAndDoneReturnsHome | FeedbackFlowUITests | 46 | 85 | 0 | 10 | kept, PR tier (moved to HappyPathUITests) |
| testOtherRegisterOptionReachesWrongRegisterFeedback | FeedbackFlowUITests | 35 | 58 | 0 | 10 | kept, full tier |
| testUnreviewedBadgeShowsOnUnreviewedItemOnlyOnQuestionAndFeedback | FeedbackFlowUITests | 33 | 48 | 0 | 10 | kept, full tier |
| testWrongItemReappearsLaterInTheSameSession | FeedbackFlowUITests | 47 | 91 | 0 | 10 | removed; rule now in the package |
| testWrongOptionReachesNotQuiteFeedback | FeedbackFlowUITests | 32 | 50 | 0 | 10 | kept, full tier |
| testCardShowsOnlyCompletionNotTheOldCounts | HomeUITests | 37 | 90 | 1 | 10 | kept, full tier |
| testCorrectAnswersRaiseTheCompletionPercent | HomeUITests | 64 | 151 | 0 | 10 | removed; rule now in the package |
| testGreetingIsAboveTheScenariosLabel | HomeUITests | 25 | 75 | 0 | 10 | kept, PR tier (moved to HappyPathUITests) |
| testMissedItemAskedAgainStaysIncompleteAfterTheSessionFinishes | HomeUITests | 71 | 220 | 0 | 10 | removed; rule now in the package |
| testOtherRegisterAnswerDoesNotCompleteTheItem | HomeUITests | 43 | 89 | 0 | 10 | removed; rule now in the package |
| testWrongAnswerDoesNotCompleteTheItem | HomeUITests | 42 | 81 | 0 | 10 | removed; rule now in the package |
| testContinueWithEmptyNameShowsErrorAndStays | OnboardingUITests | 72 | 155 | 0 | 10 | kept, full tier |
| testEnteringNameProceedsToHomeWithGreeting | OnboardingUITests | 41 | 73 | 0 | 10 | kept, PR tier (moved to HappyPathUITests) |
| testFreshLaunchShowsIntro | OnboardingUITests | 19 | 92 | 0 | 10 | kept, full tier |
| testGetStartedLeadsToNameEntry | OnboardingUITests | 33 | 148 | 0 | 10 | kept, full tier |
| testRelaunchAfterOnboardingGoesStraightToHome | OnboardingUITests | 41 | 80 | 0 | 10 | kept, full tier |
| testSeededNameSkipsOnboarding | OnboardingUITests | 16 | 27 | 0 | 10 | removed; rule now in the package |
| testAnsweredFigureAndAttemptsSurviveRelaunch | PersistenceUITests | 69 | 117 | 0 | 10 | kept, full tier |
| testConfirmedResetClearsProgressButKeepsTheName | PersistenceUITests | 63 | 79 | 0 | 10 | kept, full tier |
| testResetLaunchArgumentClearsProgress | PersistenceUITests | 61 | 97 | 0 | 10 | removed; rule now in the package |
| testResetProgressCancelChangesNothing | PersistenceUITests | 59 | 105 | 0 | 10 | removed; rule now in the package |
| testNothingImportedShowsNoRemoveButtonAndNoStatus | SettingsImportUITests | 41 | 143 | 0 | 10 | kept, full tier |
| testSettingsOffersImportLessonsWithItsHelperText | SettingsImportUITests | 33 | 122 | 0 | 10 | kept, PR tier (moved to HappyPathUITests) |

**Totals after the reshape (sum of mean test seconds, serial)**

| Set | Tests | Seconds |
|---|---:|---:|
| Before: everything | 50 | 1821 |
| Removed (rule now tested in the package) | 10 | 510 |
| PR tier (`AccessibilityUITests` + `HappyPathUITests`) | 13 | 401 |
| Full tier only | 27 | 910 |
| Full tier (everything that remains) | 40 | 1311 |

The PR tier is 401 seconds of test time (about 200 seconds on two clones) plus one build, against 1821 seconds
before. What is **not** proven here: how long the PR check takes on the runner. That needs three PR runs once a
pull request can open (see DECISIONS 045).

**What was cut or moved, and why**

- Ten UI tests were removed, each after a package test of the same rule passed (listed in the next table):
  completion figures after right, wrong and other-register answers, a missed item that comes back, an answer given
  before ending, which option leads to which feedback, what Reset cancels, and saved-name and erased-file reads.
  Two of the ten (`testSeededNameSkipsOnboarding`, `testResetLaunchArgumentClearsProgress`) tested the UI-test
  launch arguments, which every other UI test uses; the package tests cover the stored data they read.
- Kept as UI tests because the screen or the real app process is the thing under test: the layout of Home, the
  End session alert, the not-quite and other-register feedback screens, the unreviewed badge, the empty-name
  error, relaunch persistence and the confirmed Reset dialog.
- No test was placed by guesswork: a test is in the PR tier
  because it is a screen's happy path or a default-size audit, not because it is fast.

**UI tests removed, and the package test that now checks the rule** (new files under `Packages/BLTKit/Tests`)

| Removed UI test | Package test |
|---|---|
| HomeUITests.testCorrectAnswersRaiseTheCompletionPercent | BLTFeaturesTests/SessionCompletionFlowTests: correctAnswersRaiseCompletionFromZeroToFiftyToOneHundred |
| HomeUITests.testWrongAnswerDoesNotCompleteTheItem | SessionCompletionFlowTests: aWrongAnswerDoesNotCompleteTheItem |
| HomeUITests.testOtherRegisterAnswerDoesNotCompleteTheItem | SessionCompletionFlowTests: theOtherRegisterAnswerDoesNotCompleteTheItem |
| HomeUITests.testMissedItemAskedAgainStaysIncompleteAfterTheSessionFinishes | SessionCompletionFlowTests: aMissedItemAnsweredCorrectlyOnReturnStaysIncomplete |
| EndSessionUITests.testAnswerGivenBeforeEndingIsCounted | SessionCompletionFlowTests: anAnswerGivenBeforeEndingIsCounted |
| FeedbackFlowUITests.testCanonicalOptionReachesCorrectFeedback | SessionCompletionFlowTests: eachKindOfOptionLeadsToItsOwnFeedback; BLTSessionTests/FeedbackRoutingTests (three tests). The happy path still asserts the correct feedback screen. |
| FeedbackFlowUITests.testWrongItemReappearsLaterInTheSameSession | SessionCompletionFlowTests: aMissedItemComesBackBeforeTheSessionCanFinish |
| OnboardingUITests.testSeededNameSkipsOnboarding | ProgressSurvivesAndResetsFlowTests: aSavedNameIsReadBackAsTheHomeGreetingAfterReopening, aFreshInstallHasNoProfileSoOnboardingShows |
| PersistenceUITests.testResetProgressCancelChangesNothing | ProgressSurvivesAndResetsFlowTests: aCancelledResetChangesNothing |
| PersistenceUITests.testResetLaunchArgumentClearsProgress | ProgressSurvivesAndResetsFlowTests: erasingTheFileLeavesAReopenedStoreAtZeroPercentAndZeroAttempts; BLTProgressTests/ProgressReopenTests (three tests) |

Also written, with the UI tests that stay (relaunch persistence, confirmed Reset): ProgressSurvivesAndResetsFlowTests
theCompletionFigureAndAttemptCountSurviveReopeningTheFile and aConfirmedResetClearsProgressButKeepsTheName.
Package tests went from 405 to 424 as counted by the Swift Testing runner (19 new test functions), against 10 UI
tests removed.

## 2026-10-11: why one test kept "hanging", and the fix

After the reshape, PR UI jobs still took 26 to 38 minutes (goal: under 15). The slow runs had one thing in common:
the first test of a simulator clone failed once and passed on retry: `HappyPathUITests.testConfirmingEndReturnsHome`
failed after 352 seconds in one run and 794 seconds in another, then passed in about 30 seconds.

What the logs show (CI runs of PRs #22 and #26): the failure is not in the test. xcodebuild reports "the test runner
crashed while preparing to run tests ... at -[XCTWaiter(StallHandling) handleStalledWait:]" and "Early unexpected
exit, operation never finished bootstrapping", the clone logs "unable to connect to
com.apple.instruments.deviceservice.lockdown", and xcodebuild then waits 600 seconds ("Failure collecting diagnostics
from simulator: Timed out after 600.0 seconds") before the retry. That test is only the first one run in the clone.
`scripts/test.sh` let xcodebuild run classes in parallel, which boots "Clone N of iPhone 17" simulators.

Fix: `scripts/test.sh app` passes `-parallel-testing-enabled NO` (one simulator, no clones), and the CI UI job boots the
simulator and waits for it before the tests start. Measured locally on a quiet Mac: the 16 PR-tier tests passed in
279 seconds of test time (366 seconds including the app build). CI timings after the change are recorded in DECISIONS 045
when three runs are in.

