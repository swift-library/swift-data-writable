import SwiftData

/// Write actions for a SwiftData query collection.
///
/// `WritableModelCollection` is usually produced by `@Writable` as a
/// `$property` companion for an existing `@Query` array. It mutates the current
/// `ModelContext`; when `autosave` is enabled, automatic save failures are
/// swallowed. Call `save()` when the caller needs explicit error handling.
@MainActor
public struct WritableModelCollection<Base: Sequence>
where Base.Element: PersistentModel {
  /// The model type contained in the query collection.
  public typealias Element = Base.Element

  /// The current query snapshot passed to the surface.
  public let value: Base
  /// The SwiftData context used for inserts, deletes, saves, and writes.
  public let context: ModelContext
  /// Whether mutation operations should attempt a best-effort save.
  public let autosave: Bool

  /// Creates a writable surface for a query snapshot.
  public init(value: Base, context: ModelContext, autosave: Bool = false) {
    self.value = value
    self.context = context
    self.autosave = autosave
  }

  /// Inserts a model into the current `ModelContext`.
  public func append(_ model: Element) {
    context.insert(model)
    _autosave()
  }

  /// Inserts a model into the current `ModelContext`.
  public func insert(_ model: Element) {
    context.insert(model)
    _autosave()
  }

  /// Inserts each model in the sequence into the current `ModelContext`.
  public func append<S: Sequence>(contentsOf models: S) where S.Element == Element {
    for model in models {
      context.insert(model)
    }
    _autosave()
  }

  /// Deletes a model from the current `ModelContext`.
  public func delete(_ model: Element) {
    context.delete(model)
    _autosave()
  }

  /// Deletes every model in the current query snapshot.
  public func deleteAll() {
    for model in value {
      context.delete(model)
    }
    _autosave()
  }

  /// Saves the underlying `ModelContext`.
  public func save() throws {
    try context.save()
  }

  /// Runs a write closure against the underlying `ModelContext`.
  public func write(_ body: (ModelContext) throws -> Void) rethrows {
    try body(context)
    _autosave()
  }

  /// Runs a write closure with the current query snapshot and underlying context.
  @discardableResult
  public func write<Result>(
    _ body: (Base, ModelContext) throws -> Result
  ) rethrows -> Result {
    let result = try body(value, context)
    _autosave()
    return result
  }

  private func _autosave() {
    guard autosave else {
      return
    }

    try? context.save()
  }
}
