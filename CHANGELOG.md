# Changelog

## 0.1.1

- The DocC article and reference documentation show a transaction value with
  `callAsFunction` overloads. The previous example passed an overloaded static
  function, which Swift cannot resolve in a macro argument. The usage tests
  now compile and run the documented code.
- The README pins `.upToNextMinor(from: "0.1.1")`.

## 0.1.0

- Introduce `@Writable` peer projections for SwiftData query arrays, individual
  models and optional models, with a bridge for SwiftUI `@Bindable`.
- Provide query insert/delete, explicit save, value-aware writes and persisted
  reordering through a comparable ordering key path.
- Support owner relationship collection and single-model chains, with ordinary
  and throwing autosave policies and domain-owned transaction hooks.
- Keep runtime projections on the actor or executor that owns their
  `ModelContext`; SwiftUI context lookup and the Bindable bridge use the main actor.
- Require Swift 6.2, iOS 18, macOS 15, tvOS 18 or watchOS 11. Distribute source
  through SwiftPM under Apache-2.0 WITH Swift-exception.
