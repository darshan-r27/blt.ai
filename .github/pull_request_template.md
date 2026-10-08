## What and why

<!-- One or two sentences. Link the decision (docs/DECISIONS.md) if this changes one. -->

## Checklist

- [ ] `swiftlint lint --config .swiftlint.yml --strict` is clean
- [ ] `bash scripts/check-forbidden-apis.sh` is clean (no network, audio or speech APIs)
- [ ] Package tests pass; new behaviour has a test (fixtures use obviously fake `zz` text)
- [ ] UI or accessibility change: the affected UI test classes and audits were run
- [ ] Content change: it loads (package tests include the content conformance check), and review status is honest
- [ ] Docs updated if the architecture, a decision or a command changed
- [ ] Commits use the GitHub no-reply email (`bash scripts/check-identity.sh`)
