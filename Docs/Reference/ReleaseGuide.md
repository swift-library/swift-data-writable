# Release Guide

Select the version manually in `VERSION` and describe its behavior in
`CHANGELOG.md`. Review [the compatibility policy](../Architecture/VersioningAndRelease.md),
the system window, minimum Swift toolchain and dependency lock before committing
the candidate on `master`.

## Local and CI Acceptance

```sh
Scripts/check
Scripts/validate-version --require-clean --json
```

Run `Scripts/check` on the clean candidate with macOS 27's toolchain. Check the
read-only CI results for macOS 15 with Swift 6.2 and macOS 26 with Swift 6.3. Its
strict-format job uses the declared formatter toolchain. Preserve `.build/release-validation`
receipts and logs as acceptance evidence.
The DocC archive is preserved as a tarball with its checksum. Consumer evidence
includes the generated manifest, dependency lock, logs and receipt; build
directories stay outside the CI artifact.

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

Enable private vulnerability reporting in the repository before its first
publication and verify the `SECURITY.md` reporting route.

## Tag and Release

After reviewing all candidate evidence, create an annotated `vVERSION` tag at
that commit and push it. Keep published tags unchanged. Verify tagged consumption:

```sh
Scripts/validate-consumer --version "$(cat VERSION)" --ios --build-platforms \
  --output .build/tagged-consumer
```

After tagged acceptance passes, dispatch `.github/workflows/release.yml` with
that existing tag. It reruns CI on the tag and then calls the shared publisher.
The published source must match the accepted candidate. Retain native, simulator,
remote/tagged consumer receipts and dependency locks with the release evidence.
An interrupted publication can retry the same verified source and notes.
