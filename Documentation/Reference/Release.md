# Release

The repository uses the shared Swift package validation, source policy and
release workflows from
[`swift-library/github-workflows`](https://github.com/swift-library/github-workflows).

Version rules for swift-data-writable, covering tags, release timing, choosing
the next version and the changelog, are in
[VERSIONING](https://github.com/swift-library/.github/blob/master/VERSIONING.md).
This document records the repository's release facts and mechanics.

## Components and Version Sources

| Shipped component | Version meaning | Version source | Mirrors and derived fields | Update and read-only check |
| --- | --- | --- | --- | --- |
| `SwiftDataWritable` | Product version | [`VERSION`](../../VERSION), named by `version_file` in [`.github/release.json`](../../.github/release.json) | [`CHANGELOG.md`](../../CHANGELOG.md) records release notes; [`.github/release.json`](../../.github/release.json) selects the version and changelog files. | Update `VERSION` and the changelog together; shared policy and release workflows validate the declaration. |

## Compatibility Surface

Compatibility includes macro spellings, generated projection types, public runtime
methods, error policies, transaction propagation and context isolation. Query
snapshots and owner relationship membership retain their separate semantics.

## Dependencies and Validation Matrix

[`.github/swift-package.json`](../../.github/swift-package.json) declares the
compiler matrix, formatting paths, Apple platform builds, and DocC
target. [`.github/release.json`](../../.github/release.json) declares the minimum
Swift version and maintained system generations.

The package requires Swift 6.2 and SwiftSyntax 602. Its SwiftData and SwiftUI
integration requires iOS 18, macOS 15, tvOS 18 or watchOS 11.
The maintained system window is iOS 18/26/27, macOS 15/26/27,
tvOS 18/26/27 and watchOS 11/26/27.
[`Package.resolved`](../../Package.resolved) identifies the dependency revisions.

CI runs package tests and a release build on macOS 15 with Swift 6.2 and macOS 26
with Swift 6.3. Strict formatting and the `SwiftDataWritable` DocC catalog use
the last compiler entry. Apple jobs build the `swift-data-writable` scheme for
iOS, tvOS and watchOS with the selected Xcode SDKs.

Package tests cover macro expansion, persistence, context isolation, SwiftUI
context lookup, relationship transactions and detached-model errors. Apple SDK
builds validate the declared platform targets.

Dependency notices are in [`NOTICE`](../../NOTICE), and the full license terms
are in [`LICENSE.txt`](../../LICENSE.txt).

## Local Validation

Run from the package root:

```sh
swift build
swift test
swift build -c release
xcrun swift-format lint --strict --configuration .swift-format --recursive Package.swift Sources Tests
```

## Acceptance and Publication

Required checks are `policy / policy` and `validate / result`. The validation
result aggregates the compiler, formatting, Apple platform and documentation
jobs declared in `.github/swift-package.json`.

Pushing an accepted signed `vX.Y.Z` tag starts the
[`Release`](../../.github/workflows/release.yml) workflow. It validates the
tagged commit with the same package configuration, then the shared release
workflow verifies the signed annotated tag, version declaration and changelog
entry and publishes the release notes.
