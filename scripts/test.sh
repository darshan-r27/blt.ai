#!/usr/bin/env bash
# Run the BLT.ai test suites in the iOS Simulator with warnings treated as errors.
#
# Usage:
#   scripts/test.sh package [xcodebuild args...]   scheme BLTKit-Package in Packages/BLTKit
#   scripts/test.sh app     [xcodebuild args...]   scheme BLTApp in BLTApp/BLTApp.xcodeproj
#
# Environment:
#   BLT_SIM  simulator name (default "iPhone 17"); parallel agents should each use a different one
#   BLT_DD   derived data path (default ".build/dd", relative to the directory xcodebuild runs in:
#            Packages/BLTKit for `package`, the repo root for `app`). Use an absolute path to share.
#
# `package` exits 0 with a notice while Packages/BLTKit does not exist yet; `app` exits 1 if the
# Xcode project is missing.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SIM=${BLT_SIM:-iPhone 17}
DD=${BLT_DD:-.build/dd}

usage() { echo "usage: scripts/test.sh package|app [xcodebuild args...]" >&2; }

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
    PROJECT="$REPO_ROOT/BLTApp/BLTApp.xcodeproj"
    if [[ ! -d "$PROJECT" ]]; then
      echo "scripts/test.sh: error: BLTApp/BLTApp.xcodeproj not found." >&2
      exit 1
    fi
    cd "$REPO_ROOT"
    echo "scripts/test.sh: app tests on '$SIM' (derived data: $DD)"
    exec xcodebuild test \
      -project BLTApp/BLTApp.xcodeproj \
      -scheme BLTApp \
      -destination "platform=iOS Simulator,name=$SIM" \
      -derivedDataPath "$DD" \
      SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
      "$@"
    ;;
  *)
    echo "scripts/test.sh: unknown subcommand '$sub'" >&2
    usage
    exit 2
    ;;
esac
