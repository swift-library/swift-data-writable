<p align="center">
  <img src="Docs/Assets/Logo.svg" width="160" alt="swift-data-writable logo">
</p>

<h1 align="center">swift-data-writable</h1>

<p align="center">
  Projected write companions for SwiftData queries and models in SwiftUI.
</p>

<p align="center">
  <a href="https://github.com/swift-library/swift-data-writable/actions/workflows/ci.yml"><img src="https://github.com/swift-library/swift-data-writable/actions/workflows/ci.yml/badge.svg?branch=master" alt="CI"></a>
  <img src="https://img.shields.io/badge/Swift-6.2%2B-F05138" alt="Swift 6.2+">
  <img src="https://img.shields.io/badge/platforms-iOS%2018%2B%20%7C%20macOS%2015%2B%20%7C%20tvOS%2018%2B%20%7C%20watchOS%2011%2B-lightgrey" alt="Platforms: iOS 18+ | macOS 15+ | tvOS 18+ | watchOS 11+">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0-blue" alt="License: Apache-2.0 WITH Swift-exception"></a>
</p>

[Overview](#overview) · [Install](#install) · [Quick start](#quick-start) ·
[Usage](#usage) · [Requirements](#requirements) ·
[Documentation](#documentation) · [Contributing](#contributing) ·
[License](#license)

> [!NOTE]
> swift-data-writable is pre-1.0. Minor releases may include source-breaking
> changes, so depend on it with `.upToNextMinor(from:)`.

## Overview

swift-data-writable adds a write side to the SwiftData properties a SwiftUI
view already reads. Attach `@Writable` to a `@Query` array or a model property,
and the attached peer macro generates a `$property` companion that inserts, deletes,
reorders, and edits models through the view's `ModelContext`. Like a property
wrapper's projected value, the companion sits next to the property it extends,
while `@Query` stays the read-side source of truth.

- Query companions that insert and delete through `ModelContext`, including a
  function value for SwiftUI `.onDelete`.
- Persisted `.onMove` reordering through a comparable ordering key path.
- Single and optional model companions whose relationship chains stay
  writable, such as `$book.tags[0].documents`.
- Independent autosave and error policies, with domain-owned transaction
  functions around each mutation.
- A bridge from SwiftUI `@Bindable` to the same write helpers.
- Projections bound to the `ModelContext` they use, not to the main actor.

Use plain SwiftData directly when the task is schema design, migration,
container setup, CloudKit sync, query behavior without a SwiftUI editing
surface, or custom store behavior.

## Install

Add the package and the `SwiftDataWritable` product to `Package.swift`:

```swift
dependencies: [
  .package(
    url: "https://github.com/swift-library/swift-data-writable.git",
    .upToNextMinor(from: "0.1.1")
  ),
],
targets: [
  .target(
    name: "YourApp",
    dependencies: [
      .product(name: "SwiftDataWritable", package: "swift-data-writable"),
    ]
  ),
]
```

In an Xcode project, add the same URL with File > Add Package Dependencies and
choose the Up to Next Minor Version rule. `@Writable` is a Swift macro, so
Xcode asks you to trust the package before its first build.

## Quick start

Attach `@Writable` to a `@Query` array and use the generated `$persons`
companion for edits:

```swift
import SwiftData
import SwiftDataWritable
import SwiftUI

@Model
final class Person {
  var name: String

  init(name: String) {
    self.name = name
  }
}

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

@main
struct PeopleApp: App {
  var body: some Scene {
    WindowGroup {
      PeopleView()
    }
    .modelContainer(for: Person.self)
  }
}
```

`$persons` is a `WritableModelCollection<[Person]>` backed by the view's
`modelContext`. `append` inserts the new model into the context, and `remove`
deletes the models at the offsets that `.onDelete` passes. The `@Query`
snapshot refreshes after the context changes. These calls do not save on their
own: call `try $persons.save()`, enable [autosave](#saving), or let SwiftData's
own context autosave persist the change.

## Usage

The examples below use `Person`, `Book`, `Tag`, `Document`, and `Folder`
models, where a book has `tags: [Tag]`, a tag has `documents: [Document]`, and
a document has an optional `folder: Folder?`.

### Property shapes

The shape of the property decides which companion the macro generates:

| Property | Generated `$property` |
| --- | --- |
| `@Writable @Query var items: [Model]` | `WritableModelCollection<[Model]>` |
| `@Writable(autosave: true, throws: true) @Query var items: [Model]` | `ThrowsWritableModelCollection<[Model]>` |
| `@Writable(mutableBy: \Model.order) @Query var items: [Model]` | `KeyPathWritableModelCollection<[Model]>` |
| `@Writable(autosave: true, throws: true, mutableBy: \Model.order) @Query var items: [Model]` | `KeyPathThrowsWritableModelCollection<[Model]>` |
| `@Writable var model: Model` | `WritableModel<Model>` |
| `@Writable(autosave: true, throws: true) var model: Model` | `ThrowsWritableModel<Model>` |
| `@Writable var model: Model?` | `WritableModel<Model>?` |
| `@Writable @Bindable var model: Model` | None; SwiftUI keeps `$model` |

`throws: true` selects the `ThrowsWritable*` variant of each surface, and
adding `autosave:` or `transaction:` keeps the same surface type. From a model
companion, `$model.children` projects a relationship array as
`WritableRelationshipCollection<Model, [Child]>`, and `$model.child` projects a
single relationship as `WritableModel<Child>` or `WritableModel<Child>?`.
Relationship projections from a throwing surface stay throwing.

The model and relationship element types must conform to `PersistentModel`.
The macro validates the property syntax, and the generated generic constraints
let the compiler check the model conformance. The
[writable combinations reference](Docs/Reference/WritableCombinations.md)
describes each shape and method in detail.

### Query collections

A query companion writes through `ModelContext`:

```swift
@Writable
@Query(sort: \Person.name)
private var persons: [Person]
```

- `append(_:)`, `insert(_:)`, and `append(contentsOf:)` call
  `ModelContext.insert`.
- `delete(_:)` and `deleteAll()` call `ModelContext.delete`; `deleteAll()`
  deletes every model in the current snapshot.
- `remove(atOffsets:)` deletes the models at offsets in the current snapshot,
  and `$persons.remove` is the same operation as a function value for
  `.onDelete(perform:)`.
- `$persons[0]` returns a `WritableModel<Person>` for one model in the snapshot.
- `save()` calls `context.save()` and throws on failure.
- `write { context in ... }` and `write { persons, context in ... }` run a
  throwing write closure, the second with the current snapshot. The two-argument
  form returns the closure's result.

The `@Query` snapshot refreshes later, after the context changes. The
expansion is roughly:

```swift
private var _personsWritableContext = SwiftDataWritable._WritableModelContextReader()

private var `$persons`: WritableModelCollection<[Person]> {
  WritableModelCollection(
    value: persons,
    context: _personsWritableContext.context,
    autosave: false
  )
}
```

The context peer reads SwiftUI's `modelContext` environment value, and the
macro gives it a unique generated name. The companion uses the property's
access level.

`ThrowsWritableModelCollection` provides the same methods, but its mutations
throw. Because its `remove(atOffsets:)` throws, wrap it in a closure for
`.onDelete`:

```swift
.onDelete { offsets in
  try? $persons.remove(atOffsets: offsets)
}
```

### Persisted reordering

Use `@Writable(mutableBy:)` when SwiftUI `.onMove` should persist ordering by
rewriting an existing comparable field:

```swift
@Writable(mutableBy: \Person.priority)
@Query(sort: \Person.priority)
private var persons: [Person]

var body: some View {
  List {
    ForEach(persons) { person in
      Text(person.name)
    }
    .onMove(perform: $persons.move)
  }
}
```

The key path must be a writable key path to a `Comparable` value.
`move(fromOffsets:toOffset:)` reorders the current snapshot and reassigns the
original key path values to the moved models. It does not synthesize dense
integer values, so the `@Query(sort:)` key path and the `mutableBy` key path
should describe the same stored order. The companion also provides every query
collection method. `KeyPathThrowsWritableModelCollection` has a throwing
`move`, so call it from an `.onMove` closure with `try`.

### Single models

`@Writable` on a model property generates a `WritableModel`:

```swift
@Writable
private var book: Book

try $book.write { book, _ in
  book.title = "Updated"
}
```

`WritableModel` provides `save()`, `write { context in ... }`, and
`write { model, context in ... }`; the two-argument form returns the closure's
result. An optional model generates an optional companion, so use optional
chaining:

```swift
@Writable
private var selection: Person?

try $selection?.write { person, _ in
  person.name = "Updated"
}
```

### Relationships

A model companion projects its relationships, and subscripts keep the chain
writable:

```swift
@Writable
private var book: Book

@Writable
private var document: Document

$book.tags.append(tag)
$book.tags[0].documents.append(document)
try $book.tags[0].documents[0].write { document, _ in
  document.title = "Updated"
}
try $document.folder?.write { folder, _ in
  folder.name = "Manual"
}
```

A relationship collection provides `append(_:)`, `append(contentsOf:)`,
`remove(_:)`, `remove(atOffsets:)`, `removeAll()`, a subscript, `save()`, and
`write`, and `$book.tags.remove` works with `.onDelete(perform:)`. These
methods mutate the owner's relationship array directly. They do not call
`context.insert` or `context.delete`, so `$tags.append(tag)` on a query
companion inserts into the context, while `$book.tags.append(tag)` changes
`book.tags`.

This follows SwiftData's graph-root rule: insert and save the attached owner
graph, and SwiftData traverses related models automatically. When the owner is
already attached to a `ModelContext`, a new related model is persisted by
relationship mutation plus save:

```swift
let tag = Tag(name: "Swift")
$book.tags.append(tag)
try $book.save()
```

That is still relationship membership. The projection does not promise
query-style insertion, deletion, validation, inverse maintenance, or side
effects.

Single relationship projections such as `$document.folder` read the related
model without mutating the parent relationship, and they keep the autosave
setting and transaction of the chain. They exist only for `PersistentModel`
relationships, so ordinary fields remain model properties or `@Bindable`
bindings.

### Saving

`autosave` decides whether a mutation attempts `context.save()` after it
changes the context or owner relationship. `throws` decides whether an
automatic save error reaches the caller:

```swift
@Writable(autosave: true) var book: Book             // best-effort autosave
@Writable(autosave: true, throws: true) var tag: Tag // autosave failure is thrown

$persons.append(Person(name: "A")) // mutate only
try $persons.save()                // explicit save, always throws on failure
```

Ordinary `Writable*` mutation methods, such as `append`, `delete`, and `move`,
do not throw. With `autosave: true`, a save or transaction failure after the
mutation is swallowed. Explicit `save()` still throws. `write { ... }` throws
because its body can throw and a transaction can reject the mutation before it
runs.

`ThrowsWritable*` mutation methods throw. With `autosave: true`, a save failure
is thrown. `@Writable(throws: true)` without `autosave: true` is valid, but
mutations do not save; explicit `save()` remains the save point.

`autosave:` and `throws:` take literal `true` or `false` values. SwiftData's
own context autosave policy is unchanged, so with `autosave: false` a change
can still be persisted by SwiftData.

### Transaction functions

A transaction function owns the save boundary around each mutation. When
`autosave` is true and a function is supplied, swift-data-writable calls it
with the current `ModelContext`, the value, and the mutation closure, and does
not also call `context.save()`. Without `autosave: true`, the function is not
called.

```swift
enum PeopleDomain {
  static func savePeople(
    _ context: ModelContext,
    _ persons: [Person],
    _ mutation: () throws -> Void
  ) throws {
    try mutation()
    try context.save()
  }
}

@Writable(autosave: true, throws: true, transaction: PeopleDomain.savePeople)
@Query(sort: \Person.name)
private var persons: [Person]
```

The macro infers the value type from the property. A model property's function
receives the model. A query collection's function receives an array of the
affected models, which is the whole snapshot for `write`, `deleteAll()`, and
`move`. Relationship projections pass the model at the root of the chain.

Pass a non-overloaded function directly. Swift type-checks macro arguments
before expansion, so a bare overloaded function name has no property-type
context yet. When one name must support several value shapes, expose a
function-like value with `callAsFunction` overloads:

```swift
struct PeopleWriteback {
  func callAsFunction(
    _ context: ModelContext,
    _ person: Person,
    _ mutation: () throws -> Void
  ) throws {
    try mutation()
    try context.save()
  }

  func callAsFunction(
    _ context: ModelContext,
    _ persons: [Person],
    _ mutation: () throws -> Void
  ) throws {
    try mutation()
    try context.save()
  }
}

extension PeopleDomain {
  static var save: PeopleWriteback { PeopleWriteback() }
}

@Writable(autosave: true, transaction: PeopleDomain.save)
private var person: Person
```

The function runs in the same isolation context as the mutation and should
operate on the supplied `ModelContext` and value. On success it must invoke the
mutation synchronously. To reject a mutation, throw before invoking it;
returning successfully without invoking it is a programmer error that stops at
a runtime precondition. Propagate mutation errors instead of swallowing them.
On an ordinary surface, a rejection from a non-throwing method such as
`append(_:)` is silent, so use `write` or a throwing surface to observe it.

### Bindable bridge

Use `@Writable @Bindable` when a view needs both SwiftUI field bindings and
model write helpers. The macro does not generate a second `$person`; SwiftUI
keeps `$person` as `Bindable<Person>`, and its `writable` and `throwsWritable`
members bridge to the write helpers:

```swift
@Writable
@Bindable
private var person: Person

TextField("Name", text: $person.name)

try $person.writable.write { person, _ in
  person.name = "Updated"
}
try $person.writable(autosave: true).write { person, _ in
  person.name = "Updated"
}
try $person.throwsWritable(autosave: true).write { person, _ in
  person.name = "Updated"
}
```

The bridge is a runtime API without macro expansion, so it takes an explicit
`WritableTransaction<Value>`:

```swift
let transaction = WritableTransaction<Person> { context, person, mutation in
  try PeopleDomain.save(context, person, mutation)
}

try $person.throwsWritable(autosave: true, transaction: transaction).write { person, _ in
  person.name = "Updated"
}
```

The bridge reads `person.modelContext`, and a detached model throws
`WritableModelError.detachedModel`. It supports non-optional models only.

### Actors and contexts

Projections are bound to the `ModelContext` they receive, not to the main
actor. Use them from the same actor or executor that owns that context and its
models. SwiftUI context lookup and the `@Bindable` bridge are `@MainActor`
because they are SwiftUI entry points.

The surface types have public initializers, so code outside a view, such as a
`@ModelActor`, can create a projection over its own context:

```swift
@ModelActor
actor PeopleImporter {
  func rename(_ person: Person) throws {
    let writable = ThrowsWritableModel(value: person, context: modelContext, autosave: true)
    try writable.write { person, _ in
      person.name = "Imported"
    }
  }
}
```

### Domain extensions

`WritableModel` and `ThrowsWritableModel` do not define domain commands such as
rename, move, archive, or trash. Do not add thin wrappers for operations a
projection already expresses:

```swift
$book.tags.append(tag)
try $book.save()
```

Add an extension on the surface that matches your error policy when the method
carries domain meaning, such as creating related models, deduplicating,
updating inverse relationships, maintaining ordering, validating ownership, or
running side effects:

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
```

Write the same method in an extension on `ThrowsWritableModel` for throwing
companions. Relationship collections do not infer ownership fields such as
`tag.book`. A new related model does not need a manual `context.insert`; use
explicit `ModelContext` operations when the domain needs an independent
graph-root insert or delete, inverse ownership fields, validation, or side
effects.

### Unsupported shapes

The macro reports an error for these properties:

- `@Relationship`, `@Attribute`, or `@Transient` fields. Project relationships
  from a writable owner model, and edit fields with `@Bindable` or `write`.
- Arrays without `@Query`, which have no SwiftData read-side source of truth.
- `@Bindable @Query` combinations, and `@Bindable` with an optional model.
- `mutableBy:` on a single model; reordering applies only to query collections.
- Query results other than `[Model]` or `Array<Model>`, such as `Set<Model>`.
- Properties without an explicit type annotation.

swift-data-writable uses public `ModelContext` APIs such as `insert`, `delete`,
and `save`. Query execution, predicate behavior, sorting, SwiftData autosave,
and custom `DataStore` behavior remain owned by SwiftData.

## Requirements

- Swift 6.2 or later
- iOS 18 or later, macOS 15 or later, tvOS 18 or later, and watchOS 11 or
  later

The compiler minimum is maintained independently of the platform window. The
current system maintenance window is iOS 18, 26, and 27; macOS 15, 26, and 27;
tvOS 18, 26, and 27; and watchOS 11, 26, and 27. The macro implementation uses
SwiftSyntax 602, and `Package.resolved` records the revision used for
validation. The
[versioning and release policy](Docs/Architecture/VersioningAndRelease.md)
describes compatibility and maintenance: the latest released line receives
fixes, and older-line backports are evaluated per issue.

## Documentation

- [Writable combinations](Docs/Reference/WritableCombinations.md): every
  supported and rejected property shape, its generated surface, and the meaning
  of each method.
- [Architecture](Docs/Architecture/SwiftDataWritable.md): targets, the macro
  and runtime boundary, and save, relationship, and reordering semantics.
- [API documentation](Sources/SwiftDataWritable/SwiftDataWritable.docc/SwiftDataWritable.md):
  the DocC catalog.
- [Versioning and release](Docs/Architecture/VersioningAndRelease.md):
  compatibility, platform support, and maintenance.
- [Release guide](Docs/Reference/ReleaseGuide.md): validation and publication
  steps for maintainers.
- [Changelog](CHANGELOG.md)

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request, and run
`Scripts/check` before submitting changes. Report vulnerabilities through the
private route in [SECURITY.md](SECURITY.md).

## License

swift-data-writable is available under the Apache License 2.0 with the Swift
Runtime Library Exception. See [LICENSE](LICENSE) and [NOTICE](NOTICE). NOTICE
also records SwiftSyntax, a package dependency whose own license and notices
remain in its package.
