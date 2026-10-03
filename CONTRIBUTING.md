# Contributing

Read [README](README.md) for usage, [Docs/Architecture](Docs/Architecture/README.md)
for package semantics, and [the release policy](Docs/Architecture/VersioningAndRelease.md)
for compatibility and version decisions.

Work from `master`. Keep a change in its owning layer: macro syntax and
diagnostics, runtime projections, documentation or tests. Preserve the distinction
between query snapshots, owner relationship membership and SwiftUI bindings.
Describe the behavior being changed and include a regression test when a defect
affects that behavior.

Run `Scripts/check` before submitting a pull request. It checks the release
inputs, strict two-space formatting, release tooling, Swift tests, the Release
build, DocC compilation and an independent local consumer. Use `Scripts/check --format-check` or
`Scripts/check --compiler-check` for the corresponding CI scope.

Use Conventional Commit subjects such as `fix: correct save error propagation`.
To enable the local commit hook, run `git config --local core.hooksPath .githooks`.
The PR workflow also checks commit subjects.

Contributions must be yours to license under [Apache-2.0 WITH Swift-exception](LICENSE).
Preserve attribution for copied or adapted code and explain its source. Dependency
updates need compatibility, lockfile and CI review. Report security issues through
[the private reporting route](SECURITY.md).
