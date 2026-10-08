# BLT.ai — how to actually build this

> This is the original build guide, written before v1 was scoped down. The workflow that was actually used (a planning session, small chunks built in parallel by agents in worktrees, merged one at a time) is summarised in [`HANDOFF.md`](HANDOFF.md).

Written for someone who has not built an iOS app or used an agentic coding tool before. It assumes you're comfortable in a terminal and understand git conceptually.

---

## Part 1 — Before any code

### What you need

| Thing | Notes |
| --- | --- |
| Mac | Your M1 with 16GB is fine. Xcode is the heaviest thing you'll run. |
| Xcode | Free, Mac App Store, ~15GB plus another ~10GB of simulators. Install it tonight; it's slow. |
| A physical iPhone | **Non-negotiable.** Speech and microphone APIs do not work in Simulator. An iPhone able to run the app's deployment target (iOS 27, DECISIONS 029). |
| Apple ID | A free account gives you 7-day device provisioning, which is enough for all development. |
| Apple Developer Program | $99/yr, needed only for TestFlight (Task 5.5). Defer it until week 9. |
| Claude Code | See below. |
| GitHub account | Private repo until you're ready to show it. |

### Install Claude Code

On macOS:

```bash
brew install --cask claude-code
```

Or without Homebrew:

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

Then run `claude` and sign in through the browser prompt. Current setup docs: https://code.claude.com/docs/en/quickstart

### Set up the repo

```bash
mkdir blt-ai && cd blt-ai
git init
mkdir docs
# copy PRD.md, BUILD_PLAN.md, SECURITY.md into docs/
# copy CLAUDE.md into the repo ROOT, not docs/
git add -A && git commit -m "docs: PRD, build plan, security review"
```

`CLAUDE.md` goes at the repo root. Claude Code reads it automatically at the start of every session. It is the highest-leverage file in the project — most "the AI keeps doing the wrong thing" problems are actually a thin CLAUDE.md.

If you also want to use Codex, copy the same file to `AGENTS.md`. Same content, different filename convention.

---

## Part 1.5 — Hardening the dev environment

Do this before the first agent session, not after.

### The machine question

**Xcode only runs on macOS.** You cannot build, sign, or run an iOS app from a Dell — not over SSH, not in a VM, not with a cross-compiler. The Mac is the build machine. That is not negotiable and no amount of tooling changes it.

The Dell still earns a role, and a privacy-relevant one: it is the **content pipeline machine**. Everything that touches participant recordings and never touches Xcode belongs there.

| Machine | Work |
| --- | --- |
| MacBook (M1) | Xcode, all Swift, Core ML conversion (`coremltools` needs macOS), device testing |
| Dell Inspiron | Audio normalisation (ffmpeg/sox), content JSON authoring and validation, calibration notebooks, the register rule set |

The calibration set contains six learners' and three native speakers' voices, recorded under consent. Keeping that corpus on a machine that has no email client, no password manager, and no cloud sync is a real reduction in exposure, and it's a defensible line in your data-handling write-up. The Dell's 2015 hardware is irrelevant for this work — it's ffmpeg and scikit-learn, not training.

### Isolation on the Mac

Three layers, cheapest first. Do all three.

**1. A separate macOS user account.** Create a `dev` account. Do all agent work signed into it. That account has no access to your primary user's home directory, keychain, browser profiles, iCloud documents, or SSH keys. This is the strongest boundary available to you and it costs ten minutes.

Give it its own Apple ID for development signing. If something goes wrong with provisioning, the blast radius is a throwaway account.

**2. Claude Code's permission rules.** Rules live in `.claude/settings.json` at the repo root and are evaluated **deny → ask → allow, first match wins**. Commit this file; it's part of the project's security posture and it reads well in a portfolio repo.

```json
{
  "permissions": {
    "deny": [
      "Bash(curl:*)",
      "Bash(wget:*)",
      "Bash(sudo:*)",
      "Bash(rm -rf:*)",
      "Bash(git push --force:*)",
      "Bash(security:*)",
      "Read(~/.ssh/**)",
      "Read(~/.aws/**)",
      "Read(~/Library/Keychains/**)",
      "Read(./.env)",
      "Read(./secrets/**)",
      "Read(./calibration/**)"
    ],
    "ask": [
      "Bash(git push:*)",
      "Bash(brew:*)",
      "Bash(pip install:*)",
      "Bash(npm install:*)",
      "WebFetch"
    ],
    "allow": [
      "Bash(xcodebuild:*)",
      "Bash(swiftlint:*)",
      "Bash(swift test:*)",
      "Bash(git status)",
      "Bash(git diff:*)",
      "Bash(git log:*)",
      "Bash(git add:*)",
      "Bash(git commit:*)"
    ]
  },
  "defaultMode": "plan"
}
```

`defaultMode: "plan"` means every session opens in plan mode. For a first-timer that's the right default — you see the intent before anything is written.

Audit your active rules any time with `/permissions`.

**3. OS-level sandboxing.** Permissions govern what the agent *decides* to do; the sandbox governs what its Bash commands *can* do, at the OS level (Seatbelt on macOS, bubblewrap on Linux). The distinction matters: sandbox restrictions still hold even if a prompt injection subverts the agent's judgement. Permission rules alone do not survive that, so treat them as the convenience layer and the sandbox plus the separate user account as the actual boundary.

### Rules for yourself

- **Never `--dangerously-skip-permissions`** on this machine. It exists for disposable CI containers. There is no version of your workflow that needs it.
- **Commit before every task.** `git status` should be clean when you start. Then any bad session is one `git checkout .` away from undone. This is the single most effective guardrail you have, and it's free.
- **Never paste a secret into a session.** Not an API key, not a signing certificate password, not your Apple ID. Nothing in this project needs one.
- **Treat file contents as untrusted input.** If a downloaded model card, a README, or a dependency's docs contain text addressed to the agent, that's a prompt injection vector. You have almost no third-party content in this project, which is itself a mitigation — keep it that way.
- **Watch `Package.resolved`.** Any change to it is a supply-chain event. The `ask` rule above catches installs, but a manifest edit won't trip it. Check the diff.

### Two things a sandbox won't save you from

**Your own approvals.** Most agent incidents are a human clicking yes on something they didn't read. Plan mode exists so the read is cheap.

**Committed secrets.** Enable GitHub secret scanning on day one. The repo is private now but portfolio repos get made public, and git history is forever.

---

## Part 2 — The loop

This is the whole workflow. Repeat it once per task in the build plan.

### 1. Start clean

```bash
git checkout -b task-1.2-content-schema
claude
```

Then in the session, `/clear` if you've been working on something else. Context pollution is the single most common cause of an agent going off the rails — it starts pattern-matching on the last task instead of this one.

### 2. Give it the task

Paste the task block from `BUILD_PLAN.md`. Just that one block. Add one line of framing:

> Task 1.2 from docs/BUILD_PLAN.md, pasted below. Plan first, don't write code yet.
>
> [paste the task]

**Do not paste multiple tasks.** The acceptance criteria are what keep the agent honest and they get diluted when batched. This is the discipline that matters most.

### 3. Use plan mode

Shift+Tab toggles plan mode. In plan mode the agent proposes an approach and waits instead of editing files.

Read the plan. You're checking three things:

- Does it address every acceptance criterion, or did it quietly drop one?
- Is it adding a dependency or a file the task didn't call for?
- Does it violate anything in the CLAUDE.md hard constraints list?

If any of those, say so and ask for a revised plan. Reviewing a plan takes two minutes. Reviewing a wrong implementation takes an hour.

### 4. Let it work

Approve the plan. It'll write code and run tests. Press Esc to interrupt if it's clearly going wrong — you don't have to let it finish.

### 5. Review the diff

```bash
git diff
```

You're a security reviewer, not a Swift reviewer. Don't try to read every line. Check:

- The files in `SECURITY.md` → "Reviewing agent-written Swift". `AudioRecorder`, the content loader, the composition root, `Info.plist`, `Package.resolved`. That's where risk lives. SwiftUI view code is not.
- Grep for the constraint violations: `@unchecked Sendable`, `nonisolated(unsafe)`, `URLSession`, `print(`, `try!`
- Did `Package.resolved` change? If so, why? Nothing should be added without you approving it.

When you don't understand something, ask the agent directly:

> Explain what AudioRecorder.swift:40-70 does and why you wrote it that way.

And when you want a second opinion, ask it to argue against itself:

> What's the strongest case that this approach is wrong?

That prompt is unreasonably effective. Agents are agreeable by default and will usually produce a genuinely useful critique when explicitly asked to.

### 6. Verify it yourself

**Never take "done" at face value.** The most common agent failure is confidently reporting success on something that doesn't run. Build it. Run it on the device. Exercise the thing the task claimed to build.

For anything touching audio or speech, this is the only way to know — the agent literally cannot test it, because Simulator doesn't support those APIs.

### 7. Commit

```bash
git add -A
git commit -m "feat: content schema and validating loader (task 1.2)"
```

One commit per task. Referencing the task number makes the history readable, which matters for a portfolio repo.

Then `/clear` and start the next one fresh.

---

## Part 3 — What goes wrong

Recognising these early saves days.

**Scope creep.** You ask for a content loader and get a content loader plus a refactor of three unrelated files. Revert, re-prompt with a narrower ask. CLAUDE.md forbids this but agents drift, especially late in a long session.

**Confident wrongness.** Reports success, code doesn't compile or the feature doesn't work. Always build and run yourself. This is not a sign the tool is bad; it's a sign you skipped step 6.

**Silent constraint violation.** Adds a dependency, adds `@unchecked Sendable` to make a warning go away, writes to `tmp`. Grep for these on every diff. Agents optimise for the task in front of them, not for constraints stated forty turns ago.

**Context rot.** Sessions that run for hours degrade — it forgets constraints, contradicts earlier decisions, repeats work. `/clear` between tasks. If a single task is going badly for more than about forty minutes, clear and restart it with a sharper prompt rather than pushing through.

**Tests that test nothing.** Tests asserting `true == true`, or mocking the thing under test. Read the test file, not just the pass/fail. This one is easy to miss and it's the failure mode that produces a portfolio repo with 80% coverage and no actual verification.

**Agreement bias.** Ask "is this right?" and you'll get "yes." Ask "what's wrong with this?" and you'll get something useful. Phrase review questions adversarially.

---

## Part 4 — Claude Code vs Codex

Either will build this. The honest differences for your situation:

**Claude Code** — CLAUDE.md is a first-class, well-supported mechanism, and this project leans on it hard. Plan mode is good. Terminal-native, which suits an Xcode workflow where you're switching between editor and CLI anyway.

**Codex** — reads `AGENTS.md`, which is the same idea. Strong at long autonomous runs.

**The actual advice:** pick one and stay on it for the whole project. Switching mid-build means two sets of config drifting apart and inconsistent code style in a repo someone is going to read. If you want to compare them, do it deliberately: run Task 1.3 on one and Task 1.4 on the other, note the difference in `docs/DECISIONS.md`, then commit to one. That comparison is itself decent portfolio material.

Neither is going to save you from step 6. Both will produce working Swift. The differentiator is your review discipline, not the tool.

---

## Part 5 — Your first three sessions

**Session 0, no agent involved.** Create the `dev` user account and set up the permission rules from Part 1.5. Install Xcode. Build Task 0.1 by hand — it's twenty lines and you learn the Xcode create-project-and-run-on-device flow, which you need anyway. Paste the output into `docs/DECISIONS.md`.

Do this one manually on purpose. If you never build anything yourself you won't develop the instinct for when the agent's output is wrong.

**Session 1.** Task 1.1, the scaffold. Small, mechanical, and it teaches you the loop with low stakes. Expect to spend as much time on Xcode's signing and provisioning UI as on the agent.

**Session 2.** Task 1.2, the content schema. First real code. Good practice at reviewing a diff where you care about the validation logic being genuinely strict.

By session 3 the loop will feel routine and you can move faster.

---

## A note on what you're actually doing

You're not writing this app. You're specifying it, reviewing it, and verifying it — which is the TPM skillset applied to code, and it's the part that's hard to fake in an interview.

The build plan's acceptance criteria are the contract. The security checklist is the review rubric. `CLAUDE.md` is the standing instruction set. Those three documents are doing the work that a senior engineer's judgement would otherwise do, which is exactly why they were written before any code existed.

When someone asks how you built this, "I wrote the spec and the review criteria first, then had an agent implement against them one task at a time" is a much better answer than "I used AI."
