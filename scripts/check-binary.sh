#!/usr/bin/env bash
# Checks that a built BLT.ai .app does not link, or reference, anything that could reach the network
# or use audio and speech (docs/MVP_PLAN.md section 7, CLAUDE.md constraint 1). It inspects the compiled
# result, so it catches what a source scan cannot: a dependency that drags a framework in.
#
# Usage:
#   scripts/check-binary.sh <path-to-BLTApp.app>        check this built app
#   scripts/check-binary.sh <derived-data-dir>          check the newest Debug-iphonesimulator BLTApp.app
#                                                       found under that directory
#   scripts/check-binary.sh --self-test                 check the matchers against inline samples
#
# What is checked, for the app executable AND every other Mach-O file inside the bundle (embedded
# frameworks, dylibs; a Debug build puts the app's code in BLTApp.debug.dylib, so this matters):
#   * `otool -L` (direct links): fails on Network, WebKit, Speech, AVFAudio or AVFoundation, as a
#     framework or as a Swift overlay dylib (libswift<Name>.dylib), and on libnetwork.dylib.
#   * `nm -u` (undefined symbols the binary imports): fails on URLSession, NSURLConnection,
#     NWConnection and the C API nw_connection*.
#
# Exit 0 = nothing found, 1 = something found, 2 = usage or tooling error.
#
# What counts, and what does not (false positives):
#   * Only DIRECT links of the app's own binaries are failures. `otool -L` lists direct links only, so
#     a system framework that itself links Network or WebKit (SwiftUI, UIKit and Foundation do so
#     internally) never shows up here, and must not: it is not our code's doing. That is why this
#     script does not walk the dependency tree.
#   * The Swift overlay dylibs that the compiler auto-links for SwiftUI (libswiftCoreAudio,
#     libswiftXPC, libswiftCoreLocation, ...) are weak links to overlays of frameworks other than
#     the banned ones. libswiftCoreAudio is CoreAudio, not AVFAudio, so it is not flagged. A reviewer
#     should still glance at the printed link list; the script prints it for every file.
#   * Symbol matching is by substring on the mangled name, so `URLSession` also matches
#     `URLSessionConfiguration`, `NSURLSessionTask` and so on. All of those are network API.
#     `URL`, `URLResourceValues` and `URLRequest` alone do not match, so file URLs are fine.
#   * A static library linked into the app (a Swift package target) has no link line of its own; its
#     imports show up as undefined symbols of the binary it was linked into, which `nm -u` covers.
set -euo pipefail

# Banned direct links, matched against `otool -L` lines.
LINK_RE='/(Network|WebKit|Speech|AVFAudio|AVFoundation)\.framework/|/lib(swift)?(Network|WebKit|Speech|AVFAudio|AVFoundation)\.dylib|/libnetwork\.dylib'
# Banned imported symbols, matched against `nm -u` lines.
SYMBOL_RE='URLSession|NSURLConnection|NWConnection|nw_connection'

# link_hits: stdin is `otool -L` output, stdout is the offending lines.
link_hits() { grep -E "$LINK_RE" || true; }

# symbol_hits: stdin is `nm -u` output, stdout is the offending lines.
symbol_hits() { grep -E "$SYMBOL_RE" || true; }

self_test() {
  local failures=0
  expect_hit() {  # matcher label sample
    if [[ -z "$(printf '%s\n' "$3" | "$1")" ]]; then
      echo "FAIL: $2 was NOT detected: $3" >&2; failures=$((failures + 1))
    else
      echo "ok   detects $2"
    fi
  }
  expect_clean() {
    if [[ -n "$(printf '%s\n' "$3" | "$1")" ]]; then
      echo "FAIL: $2 was wrongly flagged: $3" >&2; failures=$((failures + 1))
    else
      echo "ok   passes $2"
    fi
  }
  local p='	/System/Library/Frameworks/'
  expect_hit link_hits "Network.framework" "${p}Network.framework/Network (compatibility version 1.0.0, current version 1.0.0)"
  expect_hit link_hits "WebKit.framework" "${p}WebKit.framework/WebKit (compatibility version 1.0.0, current version 1.0.0)"
  expect_hit link_hits "Speech.framework" "${p}Speech.framework/Speech (compatibility version 1.0.0, current version 1.0.0)"
  expect_hit link_hits "AVFAudio.framework" "${p}AVFAudio.framework/AVFAudio (compatibility version 1.0.0, current version 1.0.0)"
  expect_hit link_hits "AVFoundation.framework" "${p}AVFoundation.framework/AVFoundation (compatibility version 1.0.0, current version 1.0.0)"
  expect_hit link_hits "libnetwork.dylib" "	/usr/lib/libnetwork.dylib (compatibility version 1.0.0, current version 1.0.0)"
  expect_hit link_hits "Swift overlay libswiftWebKit" "	/usr/lib/swift/libswiftWebKit.dylib (compatibility version 1.0.0, current version 1.0.0)"
  expect_hit link_hits "embedded framework path" "	@rpath/Frameworks/Network.framework/Network (compatibility version 1.0.0)"
  expect_clean link_hits "Foundation.framework" "${p}Foundation.framework/Foundation (compatibility version 300.0.0, current version 5027.0.69)"
  expect_clean link_hits "SwiftUI.framework" "${p}SwiftUI.framework/SwiftUI (compatibility version 1.0.0, current version 8.0.84)"
  expect_clean link_hits "libswiftCoreAudio (CoreAudio, not AVFAudio)" "	/usr/lib/swift/libswiftCoreAudio.dylib (compatibility version 1.0.0, current version 482.102.0, weak)"
  expect_clean link_hits "libSystem" "	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1359.0.0)"
  expect_clean link_hits "the app's own debug dylib" "	@rpath/BLTApp.debug.dylib (compatibility version 0.0.0, current version 0.0.0)"
  expect_hit symbol_hits "ObjC NSURLSession" "_OBJC_CLASS_\$_NSURLSession"
  expect_hit symbol_hits "ObjC NSURLConnection" "_OBJC_CLASS_\$_NSURLConnection"
  expect_hit symbol_hits "Swift URLSession" "_\$s10Foundation10URLSessionC6sharedACvgZ"
  expect_hit symbol_hits "Swift URLSessionConfiguration" "_\$s10Foundation23URLSessionConfigurationCMa"
  expect_hit symbol_hits "Swift NWConnection" "_\$s7Network12NWConnectionCMa"
  expect_hit symbol_hits "C nw_connection_create" "_nw_connection_create"
  expect_clean symbol_hits "Swift URL" "_\$s10Foundation3URLV06isFileB0Sbvg"
  expect_clean symbol_hits "Swift URLResourceValues" "_\$s10Foundation17URLResourceValuesV13isRegularFileSbSgvg"
  expect_clean symbol_hits "os_log" "__os_log_impl"
  if (( failures > 0 )); then echo "self-test FAILED ($failures problem(s))" >&2; exit 1; fi
  echo "self-test passed"
}

usage() { sed -n '2,12p' "${BASH_SOURCE[0]}" >&2; }

# newest_app DIR: the most recently modified Debug-iphonesimulator BLTApp.app under DIR.
newest_app() {
  local found
  found=$(find "$1" -type d -name BLTApp.app -path '*Debug-iphonesimulator*' -print0 2>/dev/null \
    | xargs -0 ls -dt 2>/dev/null | head -n 1 || true)
  printf '%s' "$found"
}

# executable_name APP: CFBundleExecutable, falling back to the bundle's base name.
executable_name() {
  local app=$1 name=""
  if [[ -f "$app/Info.plist" ]]; then
    name=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app/Info.plist" 2>/dev/null || true)
  fi
  if [[ -z "$name" ]]; then name=$(basename "$app" .app); fi
  printf '%s' "$name"
}

check_app() {
  local app=$1 exe files file bad=0 count=0 links syms
  [[ -d "$app" ]] || { echo "not a directory: $app" >&2; exit 2; }
  command -v otool >/dev/null && command -v nm >/dev/null || { echo "otool and nm are required" >&2; exit 2; }
  exe=$(executable_name "$app")
  [[ -f "$app/$exe" ]] || { echo "executable not found: $exe (is this a built .app?)" >&2; exit 2; }

  # The executable first, then every other Mach-O file in the bundle.
  files=$(
    echo "$app/$exe"
    find "$app" -type f \( -name '*.dylib' -o -path '*/Frameworks/*' -o -path '*/PlugIns/*' \) -print 2>/dev/null
  )
  files=$(printf '%s\n' "$files" | awk '!seen[$0]++')

  echo "check-binary: $app"
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    case "$(file -b "$file")" in *Mach-O*) ;; *) continue ;; esac
    count=$((count + 1))
    echo "== ${file#"$app"/}"
    links=$(otool -L "$file" | tail -n +2)
    printf '%s\n' "$links" | sed 's/ (compatibility.*//; s/^[[:space:]]*/   links /'
    local link_bad symbol_bad
    link_bad=$(printf '%s\n' "$links" | link_hits)
    symbol_bad=$(nm -u "$file" 2>/dev/null | symbol_hits || true)
    if [[ -n "$link_bad" ]]; then
      bad=1
      printf '%s\n' "$link_bad" | sed 's/^/   FAIL banned link: /'
    fi
    if [[ -n "$symbol_bad" ]]; then
      bad=1
      printf '%s\n' "$symbol_bad" | sort -u | sed 's/^/   FAIL banned symbol: /'
    fi
    syms=$(nm -u "$file" 2>/dev/null | wc -l | tr -d ' ')
    echo "   ($syms undefined symbols checked)"
  done <<< "$files"

  if (( count == 0 )); then echo "no Mach-O files found in $app" >&2; exit 2; fi
  if (( bad )); then echo "check-binary: FAILED"; exit 1; fi
  echo "check-binary: clean ($count Mach-O file(s) checked)"
}

case "${1:-}" in
  --self-test) self_test ;;
  -h|--help|"") usage; [[ -n "${1:-}" ]] && exit 0 || exit 2 ;;
  *)
    target=${1%/}
    if [[ "$target" == *.app ]]; then
      app=$target
    else
      # Not an .app: treat it as a derived-data directory and look inside.
      [[ -d "$target" ]] || { echo "not a directory: $target" >&2; exit 2; }
      app=$(newest_app "$target")
      [[ -n "$app" ]] || { echo "no Debug-iphonesimulator BLTApp.app under $target" >&2; exit 2; }
    fi
    check_app "$app"
    ;;
esac
