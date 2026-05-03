# Writable Combinations

This reference describes what `@Writable` means when it is combined with
SwiftData and SwiftUI property attributes. Attribute order is not the semantic
boundary; the property shape is.

## Supported Combinations

| Source property | Generated surface | Meaning |
| --- | --- | --- |
| `@Writable @Query var items: [Model]` | `$items: WritableModelCollection<[Model]>` | `@Query` remains the read-side snapshot. `$items` mutates through `ModelContext`. |
| `@Writable(autosave: true) @Query var items: [Model]` | `$items: WritableModelCollection<[Model]>` | Same query actions, then best-effort autosave. |
| `@Writable(autosave: true, throws: true) @Query var items: [Model]` | `$items: ThrowsWritableModelCollection<[Model]>` | Same query actions, then throwing autosave. |
| `@Writable(autosave: true, throws: true, transaction: WritableTransaction<Person>.domainSave) @Query var persons: [Person]` | `$persons: ThrowsWritableModelCollection<[Person]>` | Same query actions wrapped by a typed domain autosave transaction. |
| `@Writable(mutableBy: \Model.order) @Query var items: [Model]` | `$items: KeyPathWritableModelCollection<[Model]>` | Query mutation plus persisted reorder support by rewriting existing ordering-key values. |
| `@Writable(autosave: true, throws: true, mutableBy: \Model.order) @Query var items: [Model]` | `$items: KeyPathThrowsWritableModelCollection<[Model]>` | Reorder/query actions followed by throwing autosave. |
| `@Writable var model: Model` | `$model: WritableModel<Model>` | Single attached model write surface and relationship-chain entry point. |
| `@Writable(autosave: true, throws: true) var model: Model` | `$model: ThrowsWritableModel<Model>` | Single model writes followed by throwing autosave. |
| `@Writable(autosave: true, transaction: WritableTransaction<Person>.domainSave) var person: Person` | `$person: WritableModel<Person>` | Single model writes wrapped by a typed domain autosave transaction. |
| `@Writable var model: Model?` | `$model: WritableModel<Model>?` | Optional single model write surface. Use optional chaining. |
| `@Writable @Bindable var model: Model` | No generated `$model` peer | `@Bindable` keeps `$model`. Bridge with `try $model.writable(...)` or `try $model.throwsWritable(...)`. |
| `@Writable var root: Root`, then `$root.children` | `WritableRelationshipCollection<Root, [Child]>` | Root model relationship membership mutation. |
| `@Writable(autosave: true, throws: true) var root: Root`, then `$root.children` | `ThrowsWritableRelationshipCollection<Root, [Child]>` | Root model relationship membership mutation plus throwing autosave. |

The `Model` and relationship element types must conform to `PersistentModel`.
The macro validates syntax first; generated generic constraints let the compiler
enforce SwiftData model conformance.

## Unsupported Combinations

| Source property | Why it is rejected |
| --- | --- |
| `@Writable var items: [Model]` without `@Query` | A plain local array has no SwiftData read-side source of truth. |
| `@Writable @Bindable @Query var items: [Model]` | `@Query` already owns the read snapshot and `@Bindable` does not combine with it. |
| `@Writable(mutableBy:) var model: Model` | Reordering only applies to query collections. |
| `@Writable @Bindable var model: Model?` | The bridge currently supports non-optional `Bindable<Model>` only. |
| `@Writable @Relationship var children: [Child]` | Schema relationship fields stay normal model properties; project from a writable owner model instead. |
| `@Writable @Attribute var value: Value` | Attribute fields are regular model fields, not writable roots. Use `@Bindable` or `WritableModel.write`. |
| `@Writable @Transient var value: Value` | Transient fields are regular model fields, not writable roots. Use `@Bindable` or model methods. |
| `@Writable @Query var items: Set<Model>` | Writable query collections currently support `[Model]` and `Array<Model>`. |

## Query Collection Surface

Use this form for a SwiftData query snapshot:

```swift
@Writable
@Query(sort: \Person.name)
private var persons: [Person]
```

`$persons` is a `WritableModelCollection<[Person]>`.

| Method | Meaning |
| --- | --- |
| `append(_:)`, `insert(_:)`, `append(contentsOf:)` | Insert model instances into the current `ModelContext`. The `@Query` snapshot refreshes later. |
| `delete(_:)`, `deleteAll()` | Delete model instances from the current `ModelContext`. |
| `remove(atOffsets:)`, `$persons.remove` | SwiftUI `.onDelete` convenience; deletes models at offsets in the current query snapshot. |
| `save()` | Explicitly calls `context.save()` and throws save failures. |
| `write { context in ... }` | Runs a throwing write closure. Autosave is best-effort when enabled; a transaction can reject the mutation before it runs. |
| `write { snapshot, context in ... }` | Same write boundary with the current query snapshot passed in. |

`ThrowsWritableModelCollection` mirrors the mutation methods, but mutation and
`write` are throwing because autosave failure can be surfaced.

## Reorderable Query Surface

Use this form when SwiftUI `.onMove` should persist ordering:

```swift
@Writable(mutableBy: \Person.priority)
@Query(sort: \Person.priority)
private var persons: [Person]
```

`$persons` is a `KeyPathWritableModelCollection<[Person]>`.

It supports the query collection methods plus:

| Method | Meaning |
| --- | --- |
| `move(fromOffsets:toOffset:)`, `$persons.move` | Reorders the current snapshot and rewrites the existing `mutableBy` values onto moved models. Autosave is best-effort when enabled. |

`move` does not synthesize dense order values. The `@Query(sort:)` key path and
`mutableBy` key path should describe the same stored order.

## Single Model Surface

Use this form for a model instance already available to a view:

```swift
@Writable
private var person: Person
```

`$person` is a `WritableModel<Person>`.

| Method | Meaning |
| --- | --- |
| `save()` | Explicitly calls `context.save()` and throws save failures. |
| `write { context in ... }` | Runs a write closure; closure errors are rethrown. Autosave is best-effort when enabled. |
| `write { model, context in ... }` | Same throwing write boundary with the projected model passed in. |
| `$person.relationship` | Projects a relationship collection when the key path is a writable relationship array. |

`WritableModel` and `ThrowsWritableModel` intentionally do not define domain
commands such as rename, move, archive, or trash. Downstream packages should add
those as extensions on the surface that matches their error policy.

Do not wrap projection-only operations. If all a helper does is call an
existing projection, call the projection directly:

```swift
$book.tags.append(tag)
try $book.save()
```

Use a surface extension only when the method adds a domain rule such as
creation, deduplication, inverse relationship updates, validation, ordering, or
side effects:

```swift
extension ThrowsWritableModel where Model == Book {
  @discardableResult
  func createTag(named name: String) throws -> Tag {
    try write { book, _ in
      let tag = Tag(name: name)
      book.tags.append(tag)
      return tag
    }
  }
}
```

Optional models produce an optional writable surface:

```swift
@Writable
private var person: Person?

try $person?.write { person, _ in
  person.name = "Updated"
}
```

## Bindable Compatibility

Use this form when a view still needs SwiftUI field bindings:

```swift
@Writable
@Bindable
private var person: Person
```

`@Writable` does not generate a second `$person`. SwiftUI keeps `$person` as
`Bindable<Person>`.

| Expression | Meaning |
| --- | --- |
| `$person.name` | SwiftUI `@Bindable` field binding. |
| `try $person.writable` | Bridge to `WritableModel<Person>` with `autosave: false`. |
| `try $person.writable(autosave: true)` | Bridge to best-effort autosave `WritableModel<Person>`. |
| `try $person.throwsWritable(autosave: true)` | Bridge to throwing autosave `ThrowsWritableModel<Person>`. |
| `try $person.throwsWritable(autosave: true, transaction: WritableTransaction<Person>.domainSave)` | Bridge to throwing autosave wrapped by a typed transaction. |

The bridge reads `person.modelContext`. If the model is detached from a
`ModelContext`, it throws `WritableModelError.detachedModel`.

## Relationship Collection Surface

Relationship collections are projected from a writable owner model:

```swift
@Writable
private var book: Book

$book.tags.append(tag)
$book.tags[0].documents.append(document)
```

`$book.tags` is a `WritableRelationshipCollection<Book, [Tag]>`.

| Method | Meaning |
| --- | --- |
| `append(_:)`, `append(contentsOf:)` | Mutate the owner relationship array. They do not call `context.insert`. |
| `remove(_:)`, `remove(atOffsets:)`, `$book.tags.remove` | Remove relationship membership. They do not call `context.delete`. |
| `removeAll()` | Clear relationship membership. |
| subscript, for example `$book.tags[0]` | Returns `WritableModel<Tag>` so relationship chains stay writable. |
| `save()` | Explicitly calls `context.save()` and throws save failures. |
| `write { context in ... }` | Runs a throwing write closure. Autosave is best-effort when enabled; a transaction can reject the mutation before it runs. |
| `write { relationship, context in ... }` | Same write boundary with the current relationship snapshot passed in. |

This surface expresses membership mutation only. If the relationship operation
also needs ownership back-links, validation, file-system side effects, explicit
graph-root insertion/deletion, or domain commands, put those rules in
downstream extensions or explicit `ModelContext` code.

This follows SwiftData's graph-root rule: insert/save the attached owner graph,
and SwiftData traverses related models automatically. When the owner model is
already attached to a `ModelContext`, a newly related model can be persisted by
relationship mutation plus save:

```swift
let tag = Tag(name: "Swift")
$book.tags.append(tag)
try $book.save()
```

That behavior does not turn relationship projection into a query insertion API:
the projection still only mutates membership and does not call
`context.insert`.

## Save Boundary

`autosave: false` means mutations only update the current context or owner
relationship. Persistence may still happen through SwiftData's own context
autosave.

`autosave: true` means mutations attempt `context.save()` after a successful
mutation.

If a typed `WritableTransaction<Model>` is supplied, `autosave: true` invokes
that transaction around the mutation instead of calling `context.save()` again.
This lets downstream packages register side effects or custom save/writeback
boundaries once, while projection methods stay thin:

```swift
@Writable(
  autosave: true,
  throws: true,
  transaction: WritableTransaction<Document>.bookWriteback
)
private var document: Document
```

`throws: false` means automatic save failures are swallowed. `throws: true`
means automatic save failures are thrown through `ThrowsWritable*` surfaces.
Explicit `save()` always throws on failure.
