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
- Use `Docs/README.md` and `Docs/Architecture/` for package architecture and
  current truth when they exist.
- Use `Package.swift` for package graph, products, targets, and dependencies.
- Keep source changes under `Sources/` and tests under `Tests/`.

## Authority

- `AGENTS.md` is the agent guide for package work.
- `README.md` owns user-facing behavior and examples.
- `Docs/Architecture/*` owns current architecture truth when present.
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
- Validate Swift package changes with package-local build or test checks.
