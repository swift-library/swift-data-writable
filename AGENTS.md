# swift-data-writable Agent Guide

Read `README.md` first for package purpose, public surface, and usage examples.

## First-Principles Work

- Name the behavior, root cause, invariant, owner, data flow, and validation
  before changing reusable files.
- Change the owning layer: macro surface, runtime projection, documentation, or
  tests.
- Keep source evidence and package semantics traceable to this package, not to
  one local experiment.

## Task Route

- Use `README.md` as the user-facing package manual.
- Use `Documentation/README.md` and `Documentation/Architecture/` for package architecture and
  current truth when they exist.
- Use `Package.swift` for package graph, products, targets, and dependencies.
- Keep source changes under `Sources/` and tests under `Tests/`.
- Before changing versions, dependencies, packaging or release workflows, read
  `VERSIONING.md`, or the organization VERSIONING the project adopts, for
  version rules and `Documentation/Reference/Release.md` for this repository's
  release facts and check entry points.

## Authority

- `AGENTS.md` is the agent guide for package work.
- `README.md` owns user-facing behavior and examples.
- `Documentation/Architecture/*` owns current architecture truth when present.
- `Package.swift` owns SwiftPM package structure.

## Boundary Guardrails

- Do not promote machine-local paths, one-run state, or fixture-only values into
  reusable docs, scripts, templates, or automation.
- If a value changes by input or environment, pass it in, configure it, derive
  it, or link to the owning artifact.
- Keep SwiftData and SwiftUI role boundaries explicit; do not use docs wording
  to widen macro or runtime behavior.

## Operating Notes

- Update docs when public macro behavior, generated projection semantics, or
  save/transaction behavior changes.
- Validate changes with `swift build`, `swift test`, `swift build -c release`,
  and `xcrun swift-format lint --strict --configuration .swift-format --recursive Package.swift Sources Tests`.
- `.github/swift-package.json` owns the single shared CI compiler entry
  (Xcode 26.6 on macOS 26), formatting paths, Apple platform builds, and DocC
  targets. The tools version and release minimum are Swift 6.3. Required checks are
  `policy / policy` and `validate / result`.

## Code Review Rules

### Compatibility and versioning

- Flag a change to the compatibility surface recorded in
  `Documentation/Reference/Release.md`, such as public API, observable
  behavior or a raised minimum platform or Swift version, without the
  changelog entry VERSIONING requires. Record breaking changes under
  `## Unreleased` with a **Breaking** marker and the new minimums; assign the
  version bump when preparing the release.

### Claims

- Flag README, DocC, or release-note statements that the code and tests do
  not support: capabilities that do not exist, existing behavior described as
  new, or platforms CI does not build. Safe path: describe what the code
  shows.

### Public documentation

- Flag a new public symbol without a documentation comment, and public prose
  that compares the package with other projects or describes internal
  process. Safe path: document the symbol, and describe only this package's
  own behavior.

### Tests

- Flag a behavior change without a test that would fail before the change.
  Safe path: add the test beside the existing suite for that behavior.
