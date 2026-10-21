# Contributing

Read [README](README.md) for usage, [Documentation/Architecture](Documentation/Architecture/README.md)
for package semantics, and [Release](Documentation/Reference/Release.md) for
release facts and mechanics. Version rules are in
[VERSIONING](https://github.com/swift-library/.github/blob/master/VERSIONING.md).

Work from `master`. Keep a change in its owning layer: macro syntax and
diagnostics, runtime projections, documentation or tests. Preserve the distinction
between query snapshots, owner relationship membership and SwiftUI bindings.
Describe the behavior being changed and include a regression test when a defect
affects that behavior.

Run `Scripts/check` before submitting a pull request. It checks platform declarations,
strict two-space formatting, consumer tooling, Swift tests, the Release
build, DocC compilation and an independent local consumer. Use `Scripts/check --format-check` or
`Scripts/check --compiler-check` for the corresponding CI scope.

External contributions are welcome. Use a Conventional Commit PR title such as
`fix: correct save error propagation`. Maintainers follow the shared
[signing instructions](https://github.com/swift-library/.github/blob/master/MAINTENANCE.md#signing).

Contributions must be yours to license under [Apache-2.0 WITH Swift-exception](LICENSE.txt).
Preserve attribution for copied or adapted code and explain its source. Dependency
updates need compatibility, lockfile and CI review. Report security issues through
[the private reporting route](SECURITY.md).
