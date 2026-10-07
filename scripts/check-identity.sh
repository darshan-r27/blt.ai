#!/usr/bin/env bash
# Checks that every commit's author and committer email is an allowed no-reply address, so a machine
# name or a real address is never published by accident (docs/SECURITY.md, "Repo hygiene"). Git invents
# an email such as <user>@<host>.local when none is configured, which is how that happened once.
#
# Usage:
#   scripts/check-identity.sh                 check every commit reachable from HEAD
#   scripts/check-identity.sh <rev-list args> check only those commits, e.g. origin/main..HEAD
#   scripts/check-identity.sh --self-test     check the matcher against inline samples
#
# Allowed: GitHub's per-user no-reply form (<digits>+<login>@users.noreply.github.com) and GitHub's own
# noreply@github.com, which it uses as committer for web merges. Anything else fails.
#
# Failures name the commit and the field only, never the address: CI logs are public. Look the address
# up locally with `git log -1 --format='%ae %ce' <commit>`.
#
# Exit 0 = all allowed, 1 = at least one commit has another address, 2 = usage or git error.
set -euo pipefail

ALLOWED_RE='^([0-9]+\+[A-Za-z0-9-]+@users\.noreply\.github\.com|noreply@github\.com)$'

is_allowed() { [[ "$1" =~ $ALLOWED_RE ]]; }

self_test() {
  local failures=0
  expect() { # expect <allowed|rejected> <email>
    local want=$1 email=$2 got=rejected
    if is_allowed "$email"; then got=allowed; fi
    if [[ "$got" != "$want" ]]; then
      echo "self-test FAILED: '$email' should be $want but is $got" >&2
      failures=$((failures + 1))
    fi
  }
  expect allowed  "12345+zz-user@users.noreply.github.com"
  expect allowed  "noreply@github.com"
  expect rejected "zz@zz-host.local"
  expect rejected "someone@example.com"
  expect rejected "zz-user@users.noreply.github.com"          # old form without the numeric id is not ours
  expect rejected "12345+zz-user@users.noreply.github.com.evil.example"
  expect rejected "x12345+zz-user@users.noreply.github.com "
  expect rejected ""
  if [[ $failures -ne 0 ]]; then exit 1; fi
  echo "check-identity: self-test passed"
}

if [[ "${1:-}" == "--self-test" ]]; then self_test; exit 0; fi
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then sed -n '2,17p' "$0"; exit 0; fi

log=$(git log --format='%h %ae %ce' "${@:-HEAD}") || { echo "check-identity: git log failed" >&2; exit 2; }

checked=0
bad=0
while read -r sha author committer; do
  [[ -z "$sha" ]] && continue
  checked=$((checked + 1))
  if ! is_allowed "${author:-}"; then
    echo "commit $sha: the author email is not an allowed no-reply address" >&2
    bad=$((bad + 1))
  fi
  if ! is_allowed "${committer:-}"; then
    echo "commit $sha: the committer email is not an allowed no-reply address" >&2
    bad=$((bad + 1))
  fi
done <<< "$log"

if [[ $bad -ne 0 ]]; then
  echo "check-identity: $bad problem(s) in $checked commit(s)." >&2
  echo "Set it for this repo: git config user.email <digits>+<login>@users.noreply.github.com" >&2
  echo "Fix unpushed commits: git rebase -r <base> --exec 'git commit --amend --no-edit --reset-author'" >&2
  exit 1
fi
echo "check-identity: $checked commit(s) checked, all use allowed no-reply addresses."
