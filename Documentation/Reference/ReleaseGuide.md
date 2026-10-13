# Release Guide

Follow the [shared release procedure](https://github.com/swift-library/.github/blob/master/VERSIONING.md#release-procedure)
and [package compatibility requirements](../Architecture/VersioningAndRelease.md).

## Local and CI Acceptance

```sh
Scripts/check
```

Run `Scripts/check` on the clean candidate with macOS 27's toolchain. Check the
read-only CI results for macOS 15 with Swift 6.2 and macOS 26 with Swift 6.3. Its
strict-format job uses the declared formatter toolchain. Preserve `.build/release-validation`
receipts and logs as acceptance evidence.
The DocC archive is preserved as a tarball with its checksum. Consumer evidence
includes the generated manifest, dependency lock, logs and receipt; build
directories stay outside the CI artifact.
CI installs simulator components matching its selected Xcode SDKs with
`Scripts/prepare-ci-platforms` before validation. This environment preparation
is separate from the read-only acceptance checks.

The local consumer check uses a fresh dependency graph. Before publication, push
the candidate and separately verify its remote revision:

```sh
Scripts/validate-consumer --revision "$(git rev-parse HEAD)" --ios --build-platforms \
  --output .build/remote-candidate
```

The consumer verifies macro compilation, SwiftUI context lookup, core library
behavior and declared deployment minima. The simulator phase runs each selected
iOS system generation. Use a new output path for each acceptance run and inspect
its `provenance.json`. Missing SDKs, runtimes or failing checks stop acceptance.

## Tag and Release

After creating the signed tag through the shared procedure, verify tagged consumption:

```sh
Scripts/validate-consumer --version "$(cat VERSION)" --ios --build-platforms \
  --output .build/tagged-consumer
```

Retain native, simulator, remote/tagged consumer receipts and dependency locks
with the release evidence.
