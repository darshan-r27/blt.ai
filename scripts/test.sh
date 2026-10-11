#!/usr/bin/env bash
# Run the BLT.ai test suites in the iOS Simulator with warnings treated as errors.
#
# Usage:
#   scripts/test.sh package [xcodebuild args...]      scheme BLTKit-Package in Packages/BLTKit
#   scripts/test.sh app [options] [xcodebuild args...]
#                                                     scheme BLTApp in BLTApp/BLTApp.xcodeproj
#   scripts/test.sh tiers [pr|full]                   print which UI test classes a tier selects (runs nothing)
#   scripts/test.sh flakes <xcodebuild log>           list every UI test that failed at least once in a log
#
# Options for `app` (DECISIONS 045):
#   --tier pr|full   pr   = the pull-request set: one happy path per screen plus the accessibility audits at
#                           the default text size (classes in PR_CLASSES below).
#                    full = every UI test, including the audits at the largest text size (the default).
#   --build-only     build the app and the UI tests for testing, run nothing (xcodebuild build-for-testing).
#   --no-build       run the tests from an earlier --build-only into the same BLT_DD (test-without-building).
#   With neither, one `xcodebuild test` builds and runs. CI uses the two steps so the app is built once.
#
# Environment:
#   BLT_SIM      simulator name (default "iPhone 17"); parallel agents should each use a different one
#   BLT_DD       derived data path (default ".build/dd", relative to the directory xcodebuild runs in:
#                Packages/BLTKit for `package`, the repo root for `app`). Use an absolute path to share.
#   BLT_TEST_TIMEOUT  optional, off by default: seconds one UI test may run before xcodebuild fails it. Measured
#                locally (docs/TEST_TIMINGS.md): a test that hits the limit is NOT retried by
#                -retry-tests-on-failure, so it turns a hung-then-passing attempt into a failed job. Leave unset in CI.
#
# `package` exits 0 with a notice while Packages/BLTKit does not exist yet; `app` exits 1 if the
# Xcode project is missing.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SIM=${BLT_SIM:-iPhone 17}
DD=${BLT_DD:-.build/dd}
UI_TEST_DIR="$REPO_ROOT/BLTApp/BLTAppUITests"
UI_TARGET=BLTAppUITests
UI_TIMEOUT=${BLT_TEST_TIMEOUT:-}

# The pull-request tier, by class. Every other UI test class runs only in the full tier. A new screen gets one
# happy-path test in HappyPathUITests and one default-size audit in AccessibilityUITests; nothing else is added here.
PR_CLASSES=(AccessibilityUITests HappyPathUITests)

usage() {
  echo "usage: scripts/test.sh package|app|tiers|flakes [args...]   (see the header of this file)" >&2
}

# Every UI test class in BLTAppUITests, one per line. The base classes have no tests of their own.
all_ui_classes() {
  grep -hoE '^(@MainActor )?final class [A-Za-z]+UITests' "$UI_TEST_DIR"/*.swift \
    | sed -E 's/.*class //' | sort
}

# Fails (exit 2) if a class named in PR_CLASSES no longer exists, so a rename cannot silently shrink the tier.
check_pr_classes() {
  local missing=0 class
  for class in "${PR_CLASSES[@]}"; do
    if ! all_ui_classes | grep -qx "$class"; then
      echo "scripts/test.sh: error: PR tier class '$class' not found in BLTApp/BLTAppUITests." >&2
      missing=1
    fi
  done
  [[ $missing -eq 0 ]] || exit 2
}

is_pr_class() {
  local class
  for class in "${PR_CLASSES[@]}"; do [[ "$class" == "$1" ]] && return 0; done
  return 1
}

# Lists tests that failed at least once in an xcodebuild log, and whether a later retry passed.
# Understands the parallel-testing format ("Test case 'Class.test()' failed on 'Clone 1 ...'") and the serial
# format ("Test Case '-[Module.Class test]' failed (1.0 seconds).").
flakes() {
  local log=$1
  [[ -f "$log" ]] || { echo "scripts/test.sh: error: no such log: $log" >&2; exit 2; }
  awk '
    function record(name, status) {
      if (status == "failed") failed[name]++; else passed[name]++
    }
    /Test case \047[^\047]+\047 (passed|failed) on / {
      line = $0; sub(/^.*Test case \047/, "", line)
      name = line; sub(/\047.*$/, "", name)
      rest = line; sub(/^[^\047]*\047 /, "", rest); sub(/ .*$/, "", rest)
      record(name, rest)
    }
    /Test Case \047-\[[^]]+\]\047 (passed|failed) \(/ {
      line = $0; sub(/^.*Test Case \047-\[/, "", line)
      name = line; sub(/\].*$/, "", name); gsub(/ /, ".", name)
      rest = line; sub(/^[^\047]*\047 /, "", rest); sub(/ .*$/, "", rest)
      record(name, rest)
    }
    END {
      count = 0
      for (name in failed) {
        count++
        if (passed[name] > 0) printf "RETRIED  %s  failed %d time(s), then passed\n", name, failed[name]
        else printf "FAILED   %s  failed %d time(s), never passed\n", name, failed[name]
      }
      if (count == 0) print "No UI test failed an attempt."
    }
  ' "$log" | sort
}

if [[ $# -lt 1 ]]; then usage; exit 2; fi
sub=$1; shift

case "$sub" in
  package)
    PKG_DIR="$REPO_ROOT/Packages/BLTKit"
    if [[ ! -f "$PKG_DIR/Package.swift" ]]; then
      echo "scripts/test.sh: notice: Packages/BLTKit/Package.swift not found; skipping package tests (exit 0)."
      exit 0
    fi
    cd "$PKG_DIR"
    echo "scripts/test.sh: package tests on '$SIM' (derived data: $DD)"
    exec xcodebuild test \
      -scheme BLTKit-Package \
      -destination "platform=iOS Simulator,name=$SIM" \
      -derivedDataPath "$DD" \
      SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
      "$@"
    ;;
  app)
    tier=full
    action=test
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --tier) tier=${2:-}; shift 2 || { usage; exit 2; } ;;
        --tier=*) tier=${1#--tier=}; shift ;;
        --build-only) action=build-for-testing; shift ;;
        --no-build) action=test-without-building; shift ;;
        *) break ;;
      esac
    done
    case "$tier" in pr|full) ;; *) echo "scripts/test.sh: error: --tier must be pr or full, not '$tier'." >&2; exit 2 ;; esac

    PROJECT="$REPO_ROOT/BLTApp/BLTApp.xcodeproj"
    if [[ ! -d "$PROJECT" ]]; then
      echo "scripts/test.sh: error: BLTApp/BLTApp.xcodeproj not found." >&2
      exit 1
    fi

    selection=()
    timeouts=()
    serial=()
    if [[ "$action" != build-for-testing ]]; then
      # One simulator, no clones. With parallel testing on, xcodebuild boots "Clone N of <device>" simulators, and on
      # GitHub's preview runner the test runner in a clone sometimes crashes while bootstrapping (an XCTWaiter
      # stall); xcodebuild then waits 600 seconds to collect diagnostics before the retry (352 and 794 seconds were
      # measured on one test). Serial runs avoid the clones; see docs/TEST_TIMINGS.md.
      serial=(-parallel-testing-enabled NO)
      if [[ "$tier" == pr ]]; then
        check_pr_classes
        for class in "${PR_CLASSES[@]}"; do selection+=("-only-testing:$UI_TARGET/$class"); done
      fi
      if [[ -n "$UI_TIMEOUT" ]]; then
        timeouts=(-test-timeouts-enabled YES
          -default-test-execution-time-allowance "$UI_TIMEOUT"
          -maximum-test-execution-time-allowance "$UI_TIMEOUT")
      fi
    fi

    cd "$REPO_ROOT"
    echo "scripts/test.sh: app $action, tier '$tier', on '$SIM' (derived data: $DD)"
    exec xcodebuild "$action" \
      -project BLTApp/BLTApp.xcodeproj \
      -scheme BLTApp \
      -destination "platform=iOS Simulator,name=$SIM" \
      -derivedDataPath "$DD" \
      SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
      ${selection[@]+"${selection[@]}"} \
      ${timeouts[@]+"${timeouts[@]}"} \
      ${serial[@]+"${serial[@]}"} \
      "$@"
    ;;
  tiers)
    which=${1:-both}
    check_pr_classes
    emit() {
      local class
      while read -r class; do
        if is_pr_class "$class"; then echo "pr    $class"; else echo "full  $class"; fi
      done < <(all_ui_classes)
    }
    case "$which" in
      pr) echo "PR tier selects:"; emit | awk '$1 == "pr" { print "  " $2 }' ;;
      full) echo "Full tier selects (every class):"; all_ui_classes | sed 's/^/  /' ;;
      both) echo "tier  class"; emit ;;
      *) usage; exit 2 ;;
    esac
    ;;
  flakes)
    [[ $# -eq 1 ]] || { usage; exit 2; }
    flakes "$1"
    ;;
  *)
    echo "scripts/test.sh: unknown subcommand '$sub'" >&2
    usage
    exit 2
    ;;
esac
