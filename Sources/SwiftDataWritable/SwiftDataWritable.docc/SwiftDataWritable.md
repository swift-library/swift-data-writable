# ``SwiftDataWritable``

@Metadata {
  @PageImage(purpose: icon, source: "Logo", alt: "swift-data-writable logo")
  @PageColor(blue)
}

Add projected write actions to SwiftData `@Query` collections and single
SwiftData models.

## Overview

SwiftDataWritable keeps SwiftData's read and write responsibilities separate:

- `@Query` observes and refreshes the read-side collection.
- `@Writable` generates a `$property` write-side companion.
- `ModelContext` still owns inserts, deletes, saves, and transactions.

```swift
import SwiftData
import SwiftDataWritable
import SwiftUI

struct PeopleView: View {
  @Writable
  @Query(sort: \Person.name)
  private var persons: [Person]

  var body: some View {
    List {
      ForEach(persons) { person in
        Text(person.name)
      }
      .onDelete(perform: $persons.remove)
    }
    .toolbar {
      Button("Add") {
        $persons.append(Person(name: "New"))
      }
    }
  }
}
```

Ordinary `Writable*` surfaces mutate the current `ModelContext` or owner
relationship. With `autosave: false`, they do not call `context.save()`. With
`autosave: true`, they attempt a best-effort save and swallow automatic save
failures. Explicit `save()` always throws on failure.

Writable runtime projections are isolated by the `ModelContext` and model graph
they are given, not by the main actor. Use them on the same actor or executor
that owns that context. SwiftUI context lookup and the `@Bindable` bridge remain
main-actor SwiftUI integration points.

```swift
$persons.append(Person(name: "Draft"))
try $persons.save()
```

Use `throws: true` when automatic save failure must be visible:

```swift
@Writable(autosave: true, throws: true)
@Query(sort: \Person.name)
private var persons: [Person]

try $persons.append(Person(name: "Saved"))
```

Use a transaction function when a downstream package needs to own autosave side
effects or save/writeback timing:

```swift
@Writable(
  autosave: true,
  throws: true,
  transaction: Document.writeback
)
private var document: Document
```

When a transaction function is present, SwiftDataWritable wraps it in a typed
runtime transaction, invokes it around the mutation, and does not also call
`context.save()`. The function receives `(ModelContext, Value, mutation)`,
where `Value` is the single model or the query collection array.
Use a non-overloaded function directly; use a function-like value with
`callAsFunction` overloads when one short public name should handle multiple
value shapes:

```swift
struct DocumentWriteback {
  func callAsFunction(
    _ context: ModelContext,
    _ document: Document,
    _ mutation: () throws -> Void
  ) throws {
    try mutation()
    document.revision += 1
    try context.save()
  }

  func callAsFunction(
    _ context: ModelContext,
    _ documents: [Document],
    _ mutation: () throws -> Void
  ) throws {
    try mutation()
    for document in documents {
      document.revision += 1
    }
    try context.save()
  }
}

extension Document {
  static var writeback: DocumentWriteback { DocumentWriteback() }
}
```

The transaction runs in the same isolation context as the writable mutation.
Successful hooks invoke the mutation synchronously and propagate its errors.
Throw before invoking it to reject the mutation. Returning successfully without
invoking it violates the runtime precondition.

Single model properties generate `WritableModel`:

```swift
@Writable
private var person: Person

try $person.write { person, _ in
  person.name = "Updated"
}
```

Optional model properties generate `WritableModel<Model>?`, and existing
`@Bindable` projections can bridge through `$person.writable(...)` or
`$person.throwsWritable(...)`.

`WritableModel` keeps relationship chains writable:

```swift
@Writable
private var book: Book

$book.tags.append(tag)
$book.tags[0].documents.append(document)
try $book.tags[0].documents[0].write { document, _ in
  document.title = "Updated"
}
```

Relationship collections mutate owner relationship arrays. `@Query` collection
companions remain query snapshots and use `ModelContext` insert/delete actions.
This follows SwiftData's graph-root rule: insert/save the attached owner graph,
and SwiftData traverses related models automatically. When the owner model is
already attached to a context, SwiftData can persist a newly related model
through the saved object graph, but the relationship projection itself still
only mutates membership and does not call `context.insert`.

Single relationships continue the writable chain without mutating the parent
relationship:

```swift
try $document.folder?.write { folder, _ in
  folder.name = "Manual"
}
```

Single relationship projection exists only for `PersistentModel`
relationships, so ordinary fields remain normal model properties or
`@Bindable` bindings.

Downstream extensions should add domain rules, not thin wrappers around
existing projections. Call direct membership mutations directly:

```swift
$book.tags.append(tag)
```

Extend `WritableModel` or `ThrowsWritableModel` when the method creates related
models, deduplicates, validates ownership, maintains ordering, updates inverse
relationships, or runs side effects.

## Wrapper Combinations

Use `@Writable @Query` for query snapshots, `@Writable(mutableBy:) @Query` for
query snapshots that support persisted reorder, `@Writable` on a single model
for `WritableModel`, and `@Writable @Bindable` when SwiftUI should keep the
`Bindable` projection and bridge with `$model.writable(...)` or
`$model.throwsWritable(...)`.

Do not attach `@Writable` directly to SwiftData schema fields such as
`@Relationship`, `@Attribute`, or `@Transient`. Relationship arrays stay normal
schema properties and become writable through an owner model, for example
`$book.tags`.

## Reordering

Use `@Writable(mutableBy:)` only when the query has a persistent ordering field:

```swift
@Writable(mutableBy: \Person.priority)
@Query(sort: \Person.priority)
private var persons: [Person]
```

The generated companion exposes `move(fromOffsets:toOffset:)`, which is
compatible with SwiftUI `.onMove`.

## Topics

### Macros

- ``Writable(autosave:throws:)``
- ``Writable(autosave:throws:transaction:)``
- ``Writable(autosave:throws:mutableBy:)``
- ``Writable(autosave:throws:mutableBy:transaction:)``

### Writable Runtime

- ``WritableModelCollection``
- ``KeyPathWritableModelCollection``
- ``WritableModel``
- ``WritableRelationshipCollection``

### Throws Writable Runtime

- ``ThrowsWritableModelCollection``
- ``KeyPathThrowsWritableModelCollection``
- ``ThrowsWritableModel``
- ``ThrowsWritableRelationshipCollection``
