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

Run these commands before submitting a pull request:

```sh
swift build
swift test
swift build -c release
xcrun swift-format lint --strict --configuration .swift-format --recursive Package.swift Sources Tests
```

[`.github/swift-package.json`](.github/swift-package.json) declares the shared
CI compiler matrix, formatting paths, Apple platform builds, and DocC
target. Required checks are `policy / policy` and `validate / result`.

External contributions are welcome. Use a Conventional Commit PR title such as
`fix: correct save error propagation`. Maintainers follow the shared
[signing instructions](https://github.com/swift-library/.github/blob/master/MAINTENANCE.md#signing).

Contributions must be yours to license under [Apache-2.0 WITH Swift-exception](LICENSE.txt).
Preserve attribution for copied or adapted code and explain its source. Dependency
updates need compatibility, lockfile and CI review. Report security issues through
[the private reporting route](SECURITY.md).
