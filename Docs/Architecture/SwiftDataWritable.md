# SwiftDataWritable Architecture

## Scope / Purpose

SwiftDataWritable provides a small SwiftData + SwiftUI ergonomics layer for
query collections and single models. It absorbs one Realm-style idea: a
read-side observed collection or model can have a projected write companion.

The package does not replace SwiftData CRUD, `@Query`, `@Bindable`,
`ModelContext`, schema macros, SwiftData autosave, or custom `DataStore`
implementations.

## Context / Boundaries

`@Query` remains the read-side source of truth for collection properties.
`@Writable` is an attached peer macro that validates supported property shapes
and generates a `$property` computed peer backed by SwiftUI's current
`modelContext`.

Supported source shapes:

```swift
@Writable
@Query(sort: \Person.name)
private var persons: [Person]
```

```swift
@Writable
private var person: Person
```

Unsupported source shapes include relationship fields, attribute fields,
transient fields, plain arrays without `@Query`, `@Bindable @Query`
combinations, and non-array collection spellings.

The public combination matrix and method-level meanings are documented in
[Writable Combinations](../Reference/WritableCombinations.md).

## Current Structure

The package has two implementation targets:

- `SwiftDataWritable`: public runtime support and macro declarations.
- `SwiftDataWritableMacros`: macro implementation, syntax parsing, and
  diagnostics.

The SwiftPM package identity is `swift-data-writable`. The public product,
module, and import surface remain `SwiftDataWritable`.

The public target keeps Swift files flat under `Sources/SwiftDataWritable/`.
There is no separate projection/support/domain directory because the public
types are the architecture boundary.

The runtime exposes ordinary write surfaces:

- `WritableModelCollection<Base>` for query insert/delete/write operations.
- `KeyPathWritableModelCollection<Base>` for query insert/delete/write plus
  persisted reordering with `.onMove`.
- `WritableModel<Model>` for write helpers on a single model and relationship
  dynamic-member projection.
- `WritableRelationshipCollection<Root, Base>` for non-`@Query` root model
  relationship arrays reached from `WritableModel`.

The runtime also exposes error-transparent autosave surfaces:

- `ThrowsWritableModelCollection<Base>`.
- `KeyPathThrowsWritableModelCollection<Base>`.
- `ThrowsWritableModel<Model>`.
- `ThrowsWritableRelationshipCollection<Root, Base>`.

Autosave can be customized with `WritableTransaction<Model>`, a typed
around-mutation hook that receives the active `ModelContext`, the affected
models, and the mutation closure.

The macro target generates peer declarations. For a property named `persons`,
it creates a private context peer and a `$persons` computed projection. The
context peer stores `SwiftDataWritable._WritableModelContextReader()`, a small
runtime `DynamicProperty` that reads SwiftUI's `@Environment(\.modelContext)`.
The `$persons` projection passes the reader's `context` into the runtime
surface.

## Key Principles

- Keep `@Query` untouched and observable.
- Generate write ergonomics; do not implement a query engine.
- Keep query snapshot mutation and owner relationship mutation as separate
  surfaces.
- Keep `autosave` and error exposure as separate choices.
- Keep autosave side effects in typed `WritableTransaction<Model>` hooks rather
  than baking domain save/writeback rules into the core projections.
- Preserve business meaning in ordering fields such as `priority` instead of
  requiring an implementation-specific name.
- Prefer concrete surface types over public protocols until a shared
  abstraction has a real downstream use.
- Prefer Swift standard collection constraints over package-specific model
  collection protocols.

## Save Semantics

SwiftDataWritable has one macro and two error policies.

`@Writable` and `@Writable(autosave: false)` mutate the current `ModelContext`
or owner relationship and do not call `context.save()`. Persistence may still
happen through SwiftData's own context autosave. If the caller needs an
immediate save point, the caller should use explicit `save()`.

`@Writable(autosave: true)` generates the same ordinary `Writable*` surfaces
with `autosave` enabled. Mutations attempt `context.save()` after success, but
automatic save failures are swallowed. Explicit `save()` still throws.

`@Writable(autosave: true, throws: true)` generates `ThrowsWritable*` surfaces.
Mutations save after success and throw automatic save failures.
`@Writable(throws: true)` without autosave is valid, but no automatic save
happens.

When the macro receives `transaction: WritableTransaction<Model>`, autosave
uses that transaction instead of the default `context.save()` path. The
transaction owns the around-mutation boundary and SwiftDataWritable does not
perform an additional save afterward.

Examples:

```swift
$items.append(item)                                  // mutate only
try $items.save()                                    // explicit save

@Writable(autosave: true) var book: Book             // best-effort autosave
@Writable(autosave: true, throws: true) var tag: Tag // throwing autosave
```

`write` follows the same rule: ordinary write helpers throw body or pre-mutation
transaction errors and then best-effort autosave; throws write helpers throw
body, transaction, or autosave errors.

SwiftData's own autosave policy remains SwiftData-owned.

Downstream packages define typed transactions as static surface on the concrete
model type:

```swift
extension WritableTransaction where Model == Document {
  static var writeback: Self {
    Self { context, documents, mutation in
      guard let document = documents.first else {
        try mutation()
        try context.save()
        return
      }

      try document.book.performChanges {
        try mutation()
      }
    }
  }
}
```

## Relationship Semantics

`WritableModel` is `@dynamicMemberLookup` for writable relationship collection
key paths and single `PersistentModel` relationship key paths. A
`WritableModel` such as `$book` can project `$book.tags`, and subscripts keep
the chain writable:

```swift
$book.tags[0].documents[0]
```

The result remains in the writable chain:

- `$book.tags` is `WritableRelationshipCollection<Book, [Tag]>`.
- `$book.tags[0]` is `WritableModel<Tag>`.
- `$book.tags[0].documents` is
  `WritableRelationshipCollection<Tag, [Document]>`.
- `$document.folder` is `WritableModel<Folder>?` when `folder` is an optional
  single relationship.
- The same chain from `ThrowsWritableModel` returns `ThrowsWritable*` surfaces.

Single relationship projection uses read-only `KeyPath` access because the
projection does not mutate the parent relationship; it only projects the child
model. Collection relationship projection uses `ReferenceWritableKeyPath`
because append/remove operations rewrite the owner collection.

Relationship collections mutate the owner relationship array. They do not
insert or delete models from the context. `@Query` companions keep separate
snapshot semantics: `$tags.append(tag)` inserts into `ModelContext`, while
`$book.tags.append(tag)` mutates `book.tags`.

This follows SwiftData's graph-root rule: insert/save the attached owner graph,
and SwiftData traverses related models automatically. A newly related model may
be persisted through a saved owner graph when the owner model is already
attached to a `ModelContext`. SwiftDataWritable does not take ownership of that
insertion rule; relationship projections still express membership only and
never call `context.insert` or `context.delete`.

## Bindable Compatibility

`@Writable @Bindable var person: Person` does not generate a second `$person`
projection. SwiftUI keeps `$person` as `Bindable<Person>`, and callers bridge to
model companions with `$person.writable(...)` or `$person.throwsWritable(...)`.

The bridge uses `wrappedValue.modelContext`. If the model is detached from a
context, it throws `WritableModelError.detachedModel`.

## Reordering Semantics

`@Writable(mutableBy:)` generates a `KeyPathWritableModelCollection`.

The key path value type is method-level generic and constrained to
`Comparable`. The struct remains generic only over the source collection, so the
macro can generate `KeyPathWritableModelCollection<[Person]>`.

`move(fromOffsets:toOffset:)` converts the current snapshot to an array,
applies SwiftUI's collection move behavior, then reassigns the original key path
values to the moved models. It does not synthesize dense integer values.

The `@Query(sort:)` key path and `mutableBy` key path should describe the same
stored order.

## Cross-cutting Concerns

SwiftDataWritable uses public `ModelContext` APIs such as `insert`, `delete`,
and `save`. Custom `DataStore` query behavior remains owned by SwiftData and
the active store.

The macro uses diagnostics for unsupported syntax and leaves semantic model
conformance checks to generated generic constraints.

## Risks / Known Gaps

- Swift macro peer-name support requires `arbitrary` for the generated private
  context peer.
- The generated context peer uses a runtime `_WritableModelContextReader`
  instead of a macro-generated property-wrapper peer because generated
  `@Environment` peers triggered compiler crashes in usage fixtures.
- Sectioned and searchable query ergonomics are intentionally out of scope for
  v1.
- Relationship collections do not infer domain ownership fields such as
  `tag.book`; downstream packages should still provide domain-specific helpers
  for ownership validation or construction.

## Related Decisions

There are no separate decision records yet. Current decisions are captured in
this architecture document until the package needs a decision log.
