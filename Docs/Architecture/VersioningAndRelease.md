# Versioning and Release

SwiftDataWritable adopts the organization's
[versioning and release principles](https://github.com/swift-library/.github/blob/298bf0f90708d264db72afb9469613aeaa358a55/Documentation/Architecture/VersioningAndRelease.md).
This document owns the package-specific version, compatibility surface and
validation requirements. The default branch is `master`.

## Version and Compatibility

`VERSION` owns the repository version for its single `SwiftDataWritable` library
product. A nonempty `CHANGELOG.md` entry describes that version. Tags use
`vVERSION` and bind one clean accepted commit; published tags stay immutable.
Version selection is manual and `Scripts/validate-version` only checks inputs.

Compatible fixes increase PATCH, compatible features increase MINOR. Breaking
API, macro behavior, save semantics or requirements increase MINOR during 0.x
and MAJOR from 1.0. Consumers use a next-minor range during 0.x. Documentation,
formatting and CI changes alone do not force a release.

Compatibility includes macro spellings, generated projection types, public runtime
methods, error policies, transaction propagation and context isolation. Query
snapshots and owner relationship membership retain their separate semantics.

## Platform and Compiler Support

`Package.swift` owns deployment requirements. `.github/release.json` records the
reviewed system generations and CI toolchains. The system maintenance window is
iOS 18/26/27, macOS 15/26/27, tvOS 18/26/27 and watchOS 11/26/27. Review it manually
when choosing a release. A minimum change is a compatibility change and belongs
in release notes.

Swift 6.2 is the compiler minimum, maintained independently of the system window.
The SwiftSyntax range follows the 602 series; `Package.resolved` identifies the
exact dependency accepted with a candidate.

Native macOS tests cover macro expansion, runtime persistence, context isolation
and SwiftUI integration. An independent consumer compiles at the declared iOS,
tvOS and watchOS minima and runs on each selected iOS simulator generation.
macOS 15 and 26 use CI; macOS 27 is validated locally with its matching toolchain.
SDK compilation and runtime execution are recorded as separate evidence.

## Acceptance and Publication

Run [the release guide](../Reference/ReleaseGuide.md) against an identified clean
commit. CI and local receipts identify the source/tree, dependency locks, checker
digests, toolchain, OS, SDK and completed checks. A changed input requires fresh
affected validation. Execution output belongs in ignored `.build` directories.

Remote candidate consumption must pass before a tag is created. Tag consumption
must pass before the GitHub Release is published. Inspect platform evidence before
tagging; selecting a tag is not a substitute for acceptance.

Validation workflows use read permissions and pin the shared workflow's full SHA.
The separate publication job grants contents write and actions read only after
validation passes. Retry interrupted publication with the same verified tag;
source changes after tagging require a new version.

## Maintenance and Ownership

Weekly dependency and Actions update PRs need compatibility and CI review.
Maintain the latest released line, with older-line backports decided per issue.
Contributors follow `CONTRIBUTING.md`; private reports use `SECURITY.md`.

Package source is self-owned and uses Apache-2.0 WITH Swift-exception. Required
copyright and dependency notices are in `NOTICE`; the full terms are in `LICENSE`.
Existing commits and provenance stay intact.
