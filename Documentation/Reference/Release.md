# Release

Release status: partly manual; [Scripts/check](../../Scripts/check) runs local
and CI acceptance, and remote and tagged consumption use
[Scripts/validate-consumer](../../Scripts/validate-consumer).

Version rules for swift-data-writable, covering tags, release timing, choosing
the next version and the changelog, are in
[VERSIONING](https://github.com/swift-library/.github/blob/master/VERSIONING.md).
This document records the repository's release facts and mechanics and does
not restate those rules.

## Components and Version Sources

| Shipped component | Version meaning | Version source | Mirrors and derived fields | Update and read-only check |
| --- | --- | --- | --- | --- |
| `SwiftDataWritable` | Product version | [`VERSION`](../../VERSION), named by `version_file` in [`.github/release.json`](../../.github/release.json) | [`CHANGELOG.md`](../../CHANGELOG.md) records release notes; [`.github/release.json`](../../.github/release.json) selects the version and changelog files. | Not established. |

## Compatibility Surface

Compatibility includes macro spellings, generated projection types, public runtime
methods, error policies, transaction propagation and context isolation. Query
snapshots and owner relationship membership retain their separate semantics.

## Dependencies and Verified Combinations

[`.github/release.json`](../../.github/release.json) selects the compiler matrix
and maintained system generations.

The package requires Swift 6.2 and SwiftSyntax 602. Its SwiftData and SwiftUI
integration requires iOS 18, macOS 15, tvOS 18 or watchOS 11.
The maintained system window is iOS 18/26/27, macOS 15/26/27,
tvOS 18/26/27 and watchOS 11/26/27.
[`Package.resolved`](../../Package.resolved) identifies the accepted dependency
revisions.

Native macOS tests cover macro expansion, runtime persistence, context isolation
and SwiftUI integration. An independent consumer compiles at the declared iOS,
tvOS and watchOS minima and runs on each selected iOS simulator generation.
The consumer verifies macro compilation, SwiftUI context lookup, core library
behavior and declared deployment minima.
CI tests macOS 15 with Swift 6.2 and macOS 26 with Swift 6.3; a separate job
checks strict formatting. Native macOS 27 is validated locally with its matching
toolchain. SDK compilation and runtime execution are separate evidence.

Dependency notices are in [`NOTICE`](../../NOTICE), and the full license terms
are in [`LICENSE.txt`](../../LICENSE.txt).

## Derived Metadata and Drift Checks

`Scripts/check` compares platform declarations in `Package.swift` with
`.github/release.json` and the Swift tools minimum with `minimum_swift`.
It checks strict formatting, release tooling, Swift tests, the Release build,
DocC compilation and an independent local consumer. The scoped CI commands
are listed under Entry Points and Artifact Retention.

## Candidate, Acceptance and Publication

Run `Scripts/check` on the clean candidate with macOS 27's toolchain. Check the
read-only CI results for macOS 15 with Swift 6.2 and macOS 26 with Swift 6.3. Its
strict-format job uses the declared formatter toolchain.
CI installs simulator components matching its selected Xcode SDKs with
`Scripts/prepare-ci-platforms` before validation. This environment preparation
is separate from the read-only acceptance checks.

The local consumer check uses a fresh dependency graph. Before publication, push
the candidate and separately verify its remote revision with the remote consumer
command below. After creating the signed tag, verify tagged consumption with
the tagged consumer command below. Missing SDKs, runtimes or failing checks
stop acceptance.

## Evidence Reuse and Invalidation

Preserve `.build/release-validation` receipts and logs as acceptance evidence.
The DocC archive is preserved as a tarball with its checksum. Consumer evidence
includes the generated manifest, dependency lock, logs and receipt; build
directories stay outside the CI artifact.

Use a new output path for each acceptance run and inspect its `provenance.json`.
`Scripts/validate-consumer` rejects source or checker changes during acceptance.
Retain native, simulator, remote/tagged consumer receipts and dependency locks
with the release evidence.

## Entry Points and Artifact Retention

| Operation | Existing command or explicit manual procedure | Required access |
| --- | --- | --- |
| Version update and check | Not established. | Not established. |
| Candidate validation and build | `Scripts/check`; CI uses `Scripts/check --compiler-check` and `Scripts/check --format-check`, with `Scripts/prepare-ci-platforms` before compiler validation. | Local toolchain and selected Xcode SDKs. |
| Status and interrupted-run recovery | Inspect each consumer run's `provenance.json`; use a new output path for each acceptance run. | Consumer output. |
| Acceptance and publication | Run [`Release`](../../.github/workflows/release.yml) with the accepted tag; it validates the tag and publishes the GitHub release. Remote and tagged consumer commands below. | Repository push access for the candidate; installed SDKs and runtimes; repository write access to run workflows |
| Cleanup | Not established. | Not established. |

Remote candidate consumption:

```sh
Scripts/validate-consumer --revision "$(git rev-parse HEAD)" --ios --build-platforms \
  --output .build/remote-candidate
```

Tagged consumption:

```sh
Scripts/validate-consumer --version "$(cat VERSION)" --ios --build-platforms \
  --output .build/tagged-consumer
```
