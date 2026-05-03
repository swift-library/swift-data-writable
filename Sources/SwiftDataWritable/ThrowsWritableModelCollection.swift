import SwiftData

/// Error-transparent write actions for a SwiftData query collection.
///
/// `ThrowsWritableModelCollection` mirrors `WritableModelCollection`, but
/// autosave failures are thrown to the caller.
@MainActor
public struct ThrowsWritableModelCollection<Base: Sequence>
where Base.Element: PersistentModel {
  /// The model type contained in the query collection.
  public typealias Element = Base.Element

  /// The current query snapshot passed to the surface.
  public let value: Base
  /// The SwiftData context used for inserts, deletes, saves, and writes.
  public let context: ModelContext
  /// Whether mutation operations should save after mutation.
  public let autosave: Bool

  /// Creates an error-transparent writable surface for a query snapshot.
  public init(value: Base, context: ModelContext, autosave: Bool = false) {
    self.value = value
    self.context = context
    self.autosave = autosave
  }

  /// Inserts a model into the current `ModelContext`.
  public func append(_ model: Element) throws {
    context.insert(model)
    try _autosave()
  }

  /// Inserts a model into the current `ModelContext`.
  public func insert(_ model: Element) throws {
    context.insert(model)
    try _autosave()
  }

  /// Inserts each model in the sequence into the current `ModelContext`.
  public func append<S: Sequence>(contentsOf models: S) throws where S.Element == Element {
    for model in models {
      context.insert(model)
    }
    try _autosave()
  }

  /// Deletes a model from the current `ModelContext`.
  public func delete(_ model: Element) throws {
    context.delete(model)
    try _autosave()
  }

  /// Deletes every model in the current query snapshot.
  public func deleteAll() throws {
    for model in value {
      context.delete(model)
    }
    try _autosave()
  }

  /// Saves the underlying `ModelContext`.
  public func save() throws {
    try context.save()
  }

  /// Runs a write closure against the underlying `ModelContext`.
  public func write(_ body: (ModelContext) throws -> Void) throws {
    try body(context)
    try _autosave()
  }

  /// Runs a write closure with the current query snapshot and underlying context.
  @discardableResult
  public func write<Result>(
    _ body: (Base, ModelContext) throws -> Result
  ) throws -> Result {
    let result = try body(value, context)
    try _autosave()
    return result
  }

  private func _autosave() throws {
    guard autosave else {
      return
    }

    try context.save()
  }
}
