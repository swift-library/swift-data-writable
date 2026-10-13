# Versioning and Release

SwiftDataWritable follows the [shared release standard](https://github.com/swift-library/.github/blob/master/VERSIONING.md).
`VERSION` declares the version of its `SwiftDataWritable` product, `CHANGELOG.md`
records release notes, and `.github/release.json` selects the compiler matrix
and maintained system generations.

## Compatibility surface

Compatibility includes macro spellings, generated projection types, public runtime
methods, error policies, transaction propagation and context isolation. Query
snapshots and owner relationship membership retain their separate semantics.

## Requirements and validation

The package requires Swift 6.2 and SwiftSyntax 602. Its SwiftData and SwiftUI
integration requires iOS 18, macOS 15, tvOS 18 or watchOS 11.
The maintained system window is iOS 18/26/27, macOS 15/26/27,
tvOS 18/26/27 and watchOS 11/26/27. `Package.resolved` identifies the accepted
dependency revisions.

Native macOS tests cover macro expansion, runtime persistence, context isolation
and SwiftUI integration. An independent consumer compiles at the declared iOS,
tvOS and watchOS minima and runs on each selected iOS simulator generation.
CI tests macOS 15 with Swift 6.2 and macOS 26 with Swift 6.3; a separate job
checks strict formatting. Native macOS 27 is validated locally with its matching
toolchain. SDK compilation and runtime execution are separate evidence.

The [release guide](../Reference/ReleaseGuide.md) records package-specific commands.
Evidence belongs in `.build/release-validation`. Dependency notices are in
`NOTICE`, and the full license terms are in `LICENSE.txt`.
