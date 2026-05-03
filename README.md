# SwiftDataWritable

SwiftDataWritable adds projected write companions for SwiftData `@Query`
collections and single SwiftData models in SwiftUI.

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

        Button("Add") {
            $persons.append(Person(name: "New"))
        }
    }
}
```

`@Query` remains the read-side source of truth. `@Writable` is an attached peer
macro that adds a `$property` companion backed by SwiftUI's current
`modelContext`.

## Surface Matrix

| Source | Generated surface | Meaning |
| --- | --- | --- |
| `@Writable @Query var items: [Model]` | `WritableModelCollection<[Model]>` | Query snapshot mutation through `ModelContext`. |
| `@Writable(autosave: true) @Query var items: [Model]` | `WritableModelCollection<[Model]>` | Query mutation plus best-effort autosave. |
| `@Writable(autosave: true, throws: true) @Query var items: [Model]` | `ThrowsWritableModelCollection<[Model]>` | Query mutation plus throwing autosave. |
| `@Writable(autosave: true, throws: true, transaction: WritableTransaction<Person>.domainSave) @Query var items: [Person]` | `ThrowsWritableModelCollection<[Person]>` | Query mutation plus domain-owned autosave transaction. |
| `@Writable(mutableBy:) @Query var items: [Model]` | `KeyPathWritableModelCollection<[Model]>` | Query mutation plus persisted `.onMove`. |
| `@Writable(autosave: true, throws: true, mutableBy:) @Query var items: [Model]` | `KeyPathThrowsWritableModelCollection<[Model]>` | Persisted `.onMove` plus throwing autosave. |
| `@Writable var model: Model` | `WritableModel<Model>` | Single model write and relationship-chain entry point. |
| `@Writable(autosave: true, throws: true) var model: Model` | `ThrowsWritableModel<Model>` | Single model write plus throwing autosave. |
| `@Writable(autosave: true, transaction: WritableTransaction<Person>.domainSave) var person: Person` | `WritableModel<Person>` | Single model write plus domain-owned best-effort autosave transaction. |
| `@Writable var model: Model?` | `WritableModel<Model>?` | Optional single model write; use optional chaining. |
| `@Writable @Bindable var model: Model` | no generated peer | SwiftUI keeps `$model`; bridge with `try $model.writable(...)` or `try $model.throwsWritable(...)`. |
| `$model.relationship` | `WritableRelationshipCollection<Root, [Child]>` | Root model relationship membership mutation. |
| `$model.singleRelationship` | `WritableModel<Child>` or `WritableModel<Child>?` | Single relationship projection that keeps the writable chain and autosave transaction. |

Use plain SwiftData directly when the task is schema design, migration,
container setup, CloudKit sync, query behavior without a SwiftUI editing
surface, or custom store behavior.

## Save Semantics

`autosave` only decides whether a mutation attempts `context.save()` after it
changes the context or owner relationship. `throws` only decides whether that
automatic save error is surfaced.

```swift
$persons.append(Person(name: "A"))                    // mutate only
try $persons.save()                                  // explicit save, always throws on failure

@Writable(autosave: true) var book: Book             // best-effort autosave
@Writable(autosave: true, throws: true) var tag: Tag // autosave failure is thrown
```

When `autosave` is true and a typed `WritableTransaction<Model>` is supplied,
the transaction owns the around-mutation save boundary. SwiftDataWritable calls
the transaction and does not also call `context.save()`:

```swift
@Writable(
    autosave: true,
    throws: true,
    transaction: WritableTransaction<Document>.writeback
)
var document: Document
```

Ordinary `Writable*` built-in mutation methods are non-throwing. If `autosave`
is true and SwiftData save or a transaction fails after mutation, the automatic
save error is swallowed. Explicit `save()` still throws. `write { ... }` is a
throwing API because the body can throw and a transaction can reject the
mutation before it runs.

`ThrowsWritable*` mutation methods are throwing. If `autosave` is true and
SwiftData save fails, the error is thrown. `@Writable(throws: true)` without
`autosave: true` is valid, but mutation does not save; explicit `save()` is
still the save boundary.

SwiftData's own context autosave policy remains SwiftData-owned.

## Query Collections

```swift
@Writable
@Query(sort: \Person.name)
private var persons: [Person]
```

The generated shape is:

```swift
private var _personsWritableContext = SwiftDataWritable._WritableModelContextReader()

private var $persons: WritableModelCollection<[Person]> {
    WritableModelCollection(
        value: persons,
        context: _personsWritableContext.context,
        autosave: false
    )
}
```

`WritableModelCollection` supports `append`, `insert`, `append(contentsOf:)`,
`delete`, `deleteAll`, `remove(atOffsets:)`, `$items.remove`, `save`, and
`write`. Its `append` and `delete` operations call `ModelContext.insert` and
`ModelContext.delete`; the `@Query` snapshot refreshes later.

Use `@Writable(mutableBy:)` when SwiftUI `.onMove` should persist ordering by
rewriting an existing comparable field:

```swift
@Writable(mutableBy: \Person.priority)
@Query(sort: \Person.priority)
private var persons: [Person]
```

`move(fromOffsets:toOffset:)` reorders the current snapshot and reassigns the
original key path values to the moved models. It does not synthesize dense
integer values.

## Single Models And Relationships

```swift
@Writable
private var book: Book

try $book.write { book, _ in
    book.title = "Updated"
}

$book.tags.append(tag)
$book.tags[0].documents.append(document)
try $book.tags[0].documents[0].write { document, _ in
    document.title = "Updated"
}
try $document.folder?.write { folder, _ in
    folder.name = "Manual"
}
```

Relationship collections mutate the owner relationship array directly. Single
relationships project the related model without mutating the parent
relationship. Relationship projections do not call `context.insert` or
`context.delete`; query companions keep separate snapshot semantics. This
follows SwiftData's graph-root rule: insert/save the attached owner graph, and
SwiftData traverses related models automatically.

```swift
let tag = Tag(name: "Swift")
$book.tags.append(tag)
try $book.save()
```

That is still relationship membership semantics. The projection does not
promise query-style insertion, deletion, validation, inverse maintenance, or
side effects.

Single relationship projections are intentionally model-only. They let a chain
continue through `PersistentModel` relationships without competing with
`@Bindable` for ordinary fields:

```swift
try $document.folder?.write { folder, _ in
    folder.name = "Manual"
}
```

## Bindable Bridge

Use `@Writable @Bindable` when a view needs SwiftUI field bindings and model
write helpers:

```swift
@Writable
@Bindable
private var person: Person

$person.name
try $person.writable(autosave: true).write { person, _ in
    person.name = "Updated"
}
try $person.throwsWritable(autosave: true).write { person, _ in
    person.name = "Updated"
}
```

Both bridge methods accept a typed transaction:

```swift
try $person.throwsWritable(
    autosave: true,
    transaction: WritableTransaction<Person>.domainSave
).write { person, _ in
    person.name = "Updated"
}
```

The bridge reads `person.modelContext`. Detached models throw
`WritableModelError.detachedModel`.

## Extension Points

SwiftDataWritable intentionally keeps domain behavior out of the core package.
Downstream packages should extend the surface that matches their error policy.

Do not add thin wrappers for operations the projection already expresses:

```swift
$book.tags.append(tag)
try $book.save()
```

Add downstream extensions only when the method carries real domain meaning:
creating related models, deduplicating, updating inverse relationships,
maintaining ordering, validating ownership, or running side effects.

```swift
extension WritableModel where Model == Book {
    @discardableResult
    func attachTagIfMissing(named name: String) throws -> Tag {
        try write { book, _ in
            if let existing = book.tags.first(where: { $0.name == name }) {
                return existing
            }

            let tag = Tag(name: name)
            book.tags.append(tag)
            return tag
        }
    }
}

extension ThrowsWritableModel where Model == Book {
    @discardableResult
    func attachTagIfMissing(named name: String) throws -> Tag {
        try write { book, _ in
            if let existing = book.tags.first(where: { $0.name == name }) {
                return existing
            }

            let tag = Tag(name: name)
            book.tags.append(tag)
            return tag
        }
    }
}
```

Manual `context.insert` is not required merely because the related model is new;
use explicit `ModelContext` operations when the domain needs an independent
graph-root insert/delete, inverse ownership fields, validation, or side effects.

## Boundaries

Do not use `@Writable` on:

- `@Relationship` fields
- `@Attribute` fields
- `@Transient` fields
- plain arrays without `@Query`
- `@Bindable @Query` combinations

SwiftDataWritable uses public `ModelContext` APIs. Query execution, predicate
behavior, sorting, SwiftData autosave, and custom `DataStore` behavior remain
owned by SwiftData.

## Documentation

- [Architecture](Docs/Architecture/README.md)
- [Writable Combinations](Docs/Reference/WritableCombinations.md)
- [DocC entry point](Sources/SwiftDataWritable/SwiftDataWritable.docc/SwiftDataWritable.md)
