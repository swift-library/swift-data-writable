/// Adds a projected mutation or write companion to a SwiftData `@Query`
/// collection or model.
///
/// Attach `@Writable` to an explicit `@Query` array property:
///
/// ```swift
/// @Writable
/// @Query(sort: \Person.name)
/// private var persons: [Person]
/// ```
///
/// The macro leaves `@Query` as the read-side source of truth and generates a
/// `$persons` peer backed by the current SwiftUI `modelContext`.
/// Query collection companions write through `ModelContext`; appending inserts
/// models into the context and deleting removes models from the context.
///
/// Attach `@Writable` to a single model property to generate a `WritableModel`
/// projection:
///
/// ```swift
/// @Writable
/// private var person: Person
/// ```
///
/// Optional model properties generate optional writable projections. When
/// combined with SwiftUI's `@Bindable`, `@Writable` does not generate a second
/// `$property`; use `$property.writable` to bridge into `WritableModel`.
/// `@Bindable` keeps field bindings such as `$person.name`, while the writable
/// bridge provides model-aware write helpers.
///
/// Do not attach `@Writable` directly to SwiftData schema fields such as
/// `@Relationship`, `@Attribute`, or `@Transient`. Relationship arrays are
/// projected from a writable owner model, for example `$book.tags`.
///
/// - Parameter autosave: When `true`, mutation operations attempt to save after
///   mutation. Ordinary `Writable*` surfaces swallow autosave failures.
/// - Parameter throws: When `true`, the macro generates the corresponding
///   `ThrowsWritable*` surface and autosave failures are thrown to the caller.
/// - Parameter transaction: A typed autosave hook that wraps writable
///   mutations when `autosave` is enabled.
@attached(peer, names: prefixed(`$`), arbitrary)
public macro Writable(autosave: Bool = false, throws: Bool = false) =
  #externalMacro(
    module: "SwiftDataWritableMacros",
    type: "WritableMacro"
  )

/// Adds a projected mutation or write companion with a typed autosave
/// transaction hook.
@attached(peer, names: prefixed(`$`), arbitrary)
public macro Writable<Model>(
  autosave: Bool = false,
  throws: Bool = false,
  transaction: WritableTransaction<Model>
) =
  #externalMacro(
    module: "SwiftDataWritableMacros",
    type: "WritableMacro"
  )

/// Adds a projected write companion with persistent reorder support.
///
/// Use this overload when SwiftUI `.onMove` should persist a reordered query by
/// rewriting a comparable business field:
///
/// ```swift
/// @Writable(mutableBy: \Person.priority)
/// @Query(sort: \Person.priority)
/// private var persons: [Person]
/// ```
///
/// The generated projection is a `KeyPathWritableModelCollection`.
///
/// - Parameter keyPath: A reference-writable key path whose existing values
///   define the stored order for the current query snapshot.
@attached(peer, names: prefixed(`$`), arbitrary)
public macro Writable<Root, Value: Comparable>(
  autosave: Bool = false,
  throws: Bool = false,
  mutableBy keyPath: ReferenceWritableKeyPath<Root, Value>
) =
  #externalMacro(
    module: "SwiftDataWritableMacros",
    type: "WritableMacro"
  )

/// Adds a projected reorder companion with a typed autosave transaction hook.
@attached(peer, names: prefixed(`$`), arbitrary)
public macro Writable<Root, Value: Comparable, Model>(
  autosave: Bool = false,
  throws: Bool = false,
  mutableBy keyPath: ReferenceWritableKeyPath<Root, Value>,
  transaction: WritableTransaction<Model>
) =
  #externalMacro(
    module: "SwiftDataWritableMacros",
    type: "WritableMacro"
  )
