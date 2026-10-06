#!/usr/bin/env bash
# Guardrail scan for the BLT.ai v1 bans (docs/MVP_PLAN.md section 7, CLAUDE.md hard constraints).
#
# Usage:
#   scripts/check-forbidden-apis.sh [root-dir]   scan a tree (default: repository root)
#   scripts/check-forbidden-apis.sh --self-test  check every rule against inline samples, no scan
#
# Exit 0 = clean, 1 = violations (or self-test failure). Only bash and perl; written for
# bash 3.2 (the macOS default), so no associative arrays and no mapfile.
#
# Heuristics, stated honestly:
#  * Swift lines that are entirely a `//` comment are skipped (so docs may mention a banned API).
#    Trailing comments and block comments are NOT skipped: a rule can fire inside them.
#  * `Data(contentsOf:` / `NSData(contentsOf:` is allowed only if `isFileURL` appears on the same
#    line or within the 6 preceding non-comment lines of the same file. It is a proximity check,
#    not data-flow analysis; a reviewer still reads these call sites.
#  * `https?://` is flagged anywhere on a non-comment Swift line, not only inside string literals.
#  * Rules match text, not syntax: an identifier that merely contains a banned word as a whole
#    token (for example a variable named `openURL`) is flagged too. Rename it.
set -euo pipefail

# Path prefixes (relative to the scanned root) exempt from the NETWORK rules only.
# Empty in v1. Widening this is a design change: the script fails if there is more than one entry.
EXEMPT_PATHS=()

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# --- Rule table -------------------------------------------------------------------------------
# rule SCOPE ID FLAGS REGEX NEARBY_SUPPRESS MESSAGE BAD_SAMPLE GOOD_SAMPLE
#   SCOPE: swift_all (every scanned .swift incl. tests and Package.swift)
#          swift_prod (Packages/BLTKit/Sources and BLTApp/BLTApp)
#          swift_sources (Packages/BLTKit/Sources only)
#          config (plists, entitlements, xcprivacy, project.pbxproj)
#   FLAGS: "n" = network rule (subject to EXEMPT_PATHS), "-" = none
#   Regexes are perl syntax and must not contain tab characters.
R_SCOPE=(); R_ID=(); R_FLAGS=(); R_RE=(); R_NEAR=(); R_MSG=(); R_BAD=(); R_GOOD=()
rule() {
  R_SCOPE+=("$1"); R_ID+=("$2"); R_FLAGS+=("$3"); R_RE+=("$4"); R_NEAR+=("$5")
  R_MSG+=("$6"); R_BAD+=("$7"); R_GOOD+=("$8")
}

IMPORT_PREFIX='(?:^|;)\s*(?:@\w+\s+)*(?:(?:public|internal|package)\s+)?import\s+(?:(?:struct|class|enum|protocol|func|var|let|typealias)\s+)?'

# Network
rule swift_all net-urlsession n '\bURLSession\b' '' 'network API URLSession is banned' \
  'let s = URLSession.shared' 'let s = URLSessionless'
rule swift_all net-nsurlconnection n '\bNSURLConnection\b' '' 'network API NSURLConnection is banned' \
  'NSURLConnection.sendSynchronousRequest(r)' 'let c = Connection()'
rule swift_all net-nwconnection n '\bNWConnection\b' '' 'network API NWConnection is banned' \
  'let c = NWConnection(host: h, port: p, using: .tcp)' 'let c = Connection(host: h)'
rule swift_all net-nwpathmonitor n '\bNWPathMonitor\b' '' 'network API NWPathMonitor is banned' \
  'let m = NWPathMonitor()' 'let m = PathMonitor()'
rule swift_all net-cfstream n '\b(?:CFStream|CFReadStream|CFWriteStream)' '' 'network API CFStream is banned' \
  'CFStreamCreatePairWithSocket(nil, 0, &r, &w)' 'let stream = makeStream()'
rule swift_all net-cfsocket n '\bCFSocket' '' 'network API CFSocket is banned' \
  'let s = CFSocketCreate(nil, 0, 0, 0, 0, nil, nil)' 'let s = makeSocket()'
rule swift_all net-getaddrinfo n '\bgetaddrinfo\b' '' 'network API getaddrinfo is banned' \
  'getaddrinfo(host, nil, nil, &res)' 'let info = addressInfo()'
rule swift_all net-wkwebview n '\bWKWebView' '' 'web view WKWebView is banned' \
  'let w = WKWebView(frame: .zero)' 'let w = WebViewless()'
rule swift_all net-asyncimage n '\bAsyncImage\b' '' 'AsyncImage loads remote images and is banned' \
  'AsyncImage(url: u)' 'Image("zz-asset")'
rule swift_all net-link n '\bLink\s*\(' '' 'Link( opens external URLs and is banned' \
  'Link("zz", destination: u)' 'NavigationLink("zz", value: 1)'
rule swift_all net-openurl n '\bopenURL\b' '' 'openURL opens external URLs and is banned' \
  '@Environment(\.openURL) var openURL' 'let openURLs = 1'
rule swift_all net-safari n '\bSFSafariViewController\b' '' 'SFSafariViewController is banned' \
  'let v = SFSafariViewController(url: u)' 'let v = Controller()'
rule swift_all net-webauth n '\bASWebAuthenticationSession\b' '' 'ASWebAuthenticationSession is banned' \
  'let s = ASWebAuthenticationSession(url: u, callbackURLScheme: nil)' 'let s = Session()'
rule swift_all net-import n "${IMPORT_PREFIX}(?:Network|WebKit|SafariServices|CloudKit|MultipeerConnectivity)\\b|canImport\\(\\s*(?:Network|WebKit|SafariServices|CloudKit|MultipeerConnectivity)\\s*\\)" '' \
  'import of Network, WebKit, SafariServices, CloudKit or MultipeerConnectivity is banned' \
  '@preconcurrency import WebKit' 'import Foundation'
rule swift_all net-http-literal n 'https?://' '' 'http:// or https:// literal in Swift is banned' \
  'let u = "https://example.invalid"' 'let u = "zz-example"'
rule swift_all net-data-contentsof n '\b(?:NS)?Data\s*\(\s*contentsOf\s*:' 'isFileURL' \
  'Data(contentsOf:) without a nearby isFileURL check (heuristic: same line or 6 lines above)' \
  $'let d = try Data(contentsOf: url)' \
  $'guard url.isFileURL else { throw E.notFile }\nlet d = try Data(contentsOf: url)'

# Audio and speech
rule swift_all audio-import - "${IMPORT_PREFIX}(?:AVFoundation|AVFAudio|Speech)\\b" '' \
  'import of AVFoundation, AVFAudio or Speech is banned in v1' \
  'import AVFoundation' 'import SwiftUI'
rule swift_all audio-avaudio - '\bAVAudio\w*' '' 'AVAudio* identifiers are banned in v1' \
  'let r = AVAudioRecorder()' 'let r = Recorder()'
rule swift_all audio-sfspeech - '\bSFSpeech\w*' '' 'SFSpeech* identifiers are banned in v1' \
  'let r = SFSpeechRecognizer()' 'let r = Recognizer()'

# Concurrency escapes
rule swift_all conc-unchecked-sendable - '@unchecked\s+Sendable' '' '@unchecked Sendable is banned' \
  'final class Box: @unchecked Sendable {}' 'final class Box: Sendable {}'
rule swift_all conc-nonisolated-unsafe - 'nonisolated\s*\(\s*unsafe\s*\)' '' 'nonisolated(unsafe) is banned' \
  'nonisolated(unsafe) var x = 0' 'nonisolated let x = 0'
rule swift_all conc-semaphore - '\bDispatchSemaphore\b' '' 'DispatchSemaphore is banned' \
  'let s = DispatchSemaphore(value: 0)' 'let s = DispatchQueue.main'

# Safety
rule swift_all safety-try-bang - '\btry!' '' 'try! is banned' \
  'let x = try! decode()' 'let x = try? decode()'

# Logging (shipping code only; tests may print)
rule swift_prod log-print - '(?<![\w.])print\s*\(|Swift\.print\s*\(' '' 'print( is banned in shipping code; use Logger' \
  'print("zz")' 'let blueprint = 1'
rule swift_prod log-debugprint - '\bdebugPrint\s*\(' '' 'debugPrint( is banned in shipping code; use Logger' \
  'debugPrint(x)' 'let d = debugDescription'
rule swift_prod log-nslog - '\bNSLog\s*\(' '' 'NSLog( is banned in shipping code; use Logger' \
  'NSLog("zz")' 'logger.info("zz")'

# File hygiene
rule swift_sources fs-tmpdir - '\bNSTemporaryDirectory\b|\btemporaryDirectory\b' '' \
  'temporary directory use is banned under Sources' \
  'let t = FileManager.default.temporaryDirectory' 'let t = applicationSupportURL'

# Project, plist and entitlement settings
rule config proj-outgoing-net n 'ENABLE_OUTGOING_NETWORK_CONNECTIONS' '' 'outgoing network entitlement setting is banned' \
  'ENABLE_OUTGOING_NETWORK_CONNECTIONS = YES;' 'ENABLE_APP_SANDBOX = YES;'
rule config proj-incoming-net n 'ENABLE_INCOMING_NETWORK_CONNECTIONS' '' 'incoming network entitlement setting is banned' \
  'ENABLE_INCOMING_NETWORK_CONNECTIONS = YES;' 'ENABLE_APP_SANDBOX = YES;'
rule config proj-security-network n 'com\.apple\.security\.network\.' '' 'com.apple.security.network.* entitlement is banned' \
  '<key>com.apple.security.network.client</key>' '<key>com.apple.security.app-sandbox</key>'
rule config proj-ats n 'NSAppTransportSecurity' '' 'NSAppTransportSecurity is banned' \
  '<key>NSAppTransportSecurity</key>' '<key>NSPrivacyTracking</key>'
rule config proj-usage-description - 'NS\w*UsageDescription' '' 'NS*UsageDescription keys are banned (also INFOPLIST_KEY_NS*)' \
  'INFOPLIST_KEY_NSMicrophoneUsageDescription = "zz";' 'INFOPLIST_KEY_CFBundleDisplayName = BLT.ai;'
rule config proj-file-sharing - 'UIFileSharingEnabled' '' 'UIFileSharingEnabled is banned' \
  '<key>UIFileSharingEnabled</key>' '<key>UILaunchScreen</key>'
rule config proj-open-in-place - 'LSSupportsOpeningDocumentsInPlace' '' 'LSSupportsOpeningDocumentsInPlace is banned' \
  '<key>LSSupportsOpeningDocumentsInPlace</key>' '<key>UILaunchScreen</key>'
rule config proj-dev-team - '\bDEVELOPMENT_TEAM(?:\[[^\]]*\])?"?\s*=\s*(?!(?:""|)\s*;)\S' '' \
  'DEVELOPMENT_TEAM must be empty (no team ID in the repo)' \
  'DEVELOPMENT_TEAM = ABCDE12345;' 'DEVELOPMENT_TEAM = "";'

# --- Matching engine (perl) -------------------------------------------------------------------
# Input: env RULES (one per line: id TAB flags TAB regex TAB nearby TAB message), env ROOT, env EXEMPT
# (newline-separated prefixes). Either env SAMPLE + env LABEL (virtual file) or file names on stdin.
# Prints "path:line: [rule] message" per hit; exit status is 1 if there was any hit.
read -r -d '' PERL_ENGINE <<'PERL' || true
use strict; use warnings;
my @rules;
for my $line (split /\n/, $ENV{RULES} // '') {
  next unless length $line;
  my ($id, $flags, $re, $near, $msg) = split /\t/, $line, 5;
  push @rules, { id => $id, net => ($flags =~ /n/ ? 1 : 0), re => qr/$re/,
                 near => (length($near // '') ? qr/$near/ : undef), msg => $msg };
}
my @exempt = grep { length } split /\n/, ($ENV{EXEMPT} // '');
my $root = $ENV{ROOT} // '';
my $hits = 0;
sub scan {
  my ($rel, @lines) = @_;
  my $swift = ($rel =~ /\.swift$/) ? 1 : 0;
  my $exempt = 0;
  for my $p (@exempt) { $exempt = 1 if index($rel, $p) == 0 }
  my @hist;
  my $n = 0;
  for my $l (@lines) {
    $n++;
    next if $swift && $l =~ m{^\s*//};
    for my $r (@rules) {
      next if $r->{net} && $exempt;
      next unless $l =~ $r->{re};
      if ($r->{near}) {
        next if $l =~ $r->{near};
        next if grep { $_ =~ $r->{near} } @hist;
      }
      print "$rel:$n: [$r->{id}] $r->{msg}\n";
      $hits++;
    }
    push @hist, $l; shift @hist if @hist > 6;
  }
}
if (defined $ENV{SAMPLE}) {
  scan($ENV{LABEL} // 'sample.swift', split /\n/, $ENV{SAMPLE});
} else {
  while (my $f = <STDIN>) {
    chomp $f; next unless length $f;
    my $rel = $f; $rel =~ s{^\Q$root\E/}{};
    open(my $fh, '<', $f) or do { print "$rel:0: [io] cannot read file\n"; $hits++; next };
    my @lines = <$fh>; close $fh; chomp @lines;
    scan($rel, @lines);
  }
}
exit($hits ? 1 : 0);
PERL

exempt_env() {
  local out="" p
  for p in ${EXEMPT_PATHS[@]+"${EXEMPT_PATHS[@]}"}; do out="${out}${p}"$'\n'; done
  printf '%s' "$out"
}

# rules_for SCOPE [INDEX]: emit rule lines for a scope (or a single rule index when given).
rules_for() {
  local scope=$1 only=${2:-} i
  for ((i = 0; i < ${#R_ID[@]}; i++)); do
    if [[ -n "$only" ]]; then
      [[ "$only" == "$i" ]] || continue
    else
      [[ "${R_SCOPE[$i]}" == "$scope" ]] || continue
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "${R_ID[$i]}" "${R_FLAGS[$i]}" "${R_RE[$i]}" "${R_NEAR[$i]}" "${R_MSG[$i]}"
  done
}

label_for_scope() { if [[ "$1" == config ]]; then echo sample.pbxproj; else echo sample.swift; fi; }

check_exempt_paths() {
  if (( ${#EXEMPT_PATHS[@]} > 1 )); then
    echo "FAIL: EXEMPT_PATHS has ${#EXEMPT_PATHS[@]} entries; at most one is allowed. Widening it is a design change." >&2
    return 1
  fi
}

self_test() {
  local failures=0 i rules label netrules
  check_exempt_paths || failures=$((failures + 1))
  if (( ${#R_ID[@]} == 0 )); then echo "FAIL: no rules defined" >&2; exit 1; fi
  for ((i = 0; i < ${#R_ID[@]}; i++)); do
    rules=$(rules_for "" "$i")
    label=$(label_for_scope "${R_SCOPE[$i]}")
    if RULES="$rules" SAMPLE="${R_BAD[$i]}" LABEL="$label" ROOT="" EXEMPT="" perl -e "$PERL_ENGINE" </dev/null >/dev/null; then
      echo "FAIL ${R_ID[$i]}: violating sample was NOT detected" >&2; failures=$((failures + 1)); continue
    fi
    if ! RULES="$rules" SAMPLE="${R_GOOD[$i]}" LABEL="$label" ROOT="" EXEMPT="" perl -e "$PERL_ENGINE" </dev/null >/dev/null; then
      echo "FAIL ${R_ID[$i]}: clean sample was wrongly flagged" >&2; failures=$((failures + 1)); continue
    fi
    echo "ok   ${R_ID[$i]}"
  done
  # Mechanism checks (rule 0 is a network rule): comment-only lines skipped; exemption is prefix-based.
  netrules=$(rules_for "" 0)
  if ! RULES="$netrules" SAMPLE='// URLSession is banned' LABEL=sample.swift ROOT="" EXEMPT="" perl -e "$PERL_ENGINE" </dev/null >/dev/null; then
    echo "FAIL: full-line comment should be skipped" >&2; failures=$((failures + 1))
  fi
  if ! RULES="$netrules" SAMPLE='let s = URLSession.shared' LABEL=zz/exempt.swift ROOT="" EXEMPT="zz/" perl -e "$PERL_ENGINE" </dev/null >/dev/null; then
    echo "FAIL: exempt prefix should suppress network rules" >&2; failures=$((failures + 1))
  fi
  if (( failures > 0 )); then echo "self-test FAILED ($failures problem(s))" >&2; exit 1; fi
  echo "self-test passed (${#R_ID[@]} rules)"
}

# --- Scan -------------------------------------------------------------------------------------
# find_in ROOT NAME-GLOB DIR...: list matching files under each existing DIR (missing ones are skipped).
find_in() {
  local root=$1 glob=$2; shift 2
  local d
  for d in "$@"; do
    [[ -d "$root/$d" ]] || continue
    find "$root/$d" \( -name .build -o -name DerivedData -o -name xcuserdata -o -name node_modules -o -name .git \) -prune \
      -o -type f -name "$glob" -print
  done
}

scope_files() {
  local root=$1 scope=$2 g
  case "$scope" in
    swift_all)
      find_in "$root" '*.swift' Packages/BLTKit/Sources Packages/BLTKit/Tests BLTApp/BLTApp BLTApp/BLTAppUITests
      [[ -f "$root/Package.swift" ]] && echo "$root/Package.swift"
      [[ -f "$root/Packages/BLTKit/Package.swift" ]] && echo "$root/Packages/BLTKit/Package.swift"
      ;;
    swift_prod) find_in "$root" '*.swift' Packages/BLTKit/Sources BLTApp/BLTApp ;;
    swift_sources) find_in "$root" '*.swift' Packages/BLTKit/Sources ;;
    config)
      for g in '*.plist' '*.entitlements' '*.xcprivacy'; do
        find_in "$root" "$g" Packages/BLTKit/Sources Packages/BLTKit/Tests BLTApp
      done
      [[ -f "$root/BLTApp/BLTApp.xcodeproj/project.pbxproj" ]] && echo "$root/BLTApp/BLTApp.xcodeproj/project.pbxproj"
      ;;
  esac
  return 0
}

scan() {
  local root=$1 scope files rules out total=0
  check_exempt_paths || exit 1
  for scope in swift_all swift_prod swift_sources config; do
    files=$(scope_files "$root" "$scope" | sort -u)
    [[ -n "$files" ]] || continue
    rules=$(rules_for "$scope")
    if ! out=$(printf '%s\n' "$files" | RULES="$rules" ROOT="$root" EXEMPT="$(exempt_env)" perl -e "$PERL_ENGINE"); then
      printf '%s\n' "$out"
      total=$((total + $(printf '%s\n' "$out" | grep -c .)))
    fi
  done
  if (( total > 0 )); then
    echo "FAILED: $total violation(s)." >&2
    exit 1
  fi
  echo "check-forbidden-apis: clean ($root)"
}

case "${1:-}" in
  --self-test) self_test ;;
  -h|--help) sed -n '2,8p' "${BASH_SOURCE[0]}" ;;
  *)
    ROOT=${1:-$(cd "$SCRIPT_DIR/.." && pwd)}
    [[ -d "$ROOT" ]] || { echo "root directory not found: $ROOT" >&2; exit 2; }
    scan "$(cd "$ROOT" && pwd)"
    ;;
esac
