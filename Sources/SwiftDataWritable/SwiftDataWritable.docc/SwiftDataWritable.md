# ``SwiftDataWritable``

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

Single model properties generate `WritableModel`:

```swift
@Writable
private var person: Person

$person.write { person, _ in
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
$book.tags[0].documents[0].write { document, _ in
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
- ``Writable(autosave:throws:mutableBy:)``

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
