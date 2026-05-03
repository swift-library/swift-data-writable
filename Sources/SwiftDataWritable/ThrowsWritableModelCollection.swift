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
  /// Optional autosave transaction hook for affected collection elements.
  public let transaction: WritableTransaction<Element>?

  /// Creates an error-transparent writable surface for a query snapshot.
  public init(
    value: Base,
    context: ModelContext,
    autosave: Bool = false,
    transaction: WritableTransaction<Element>? = nil
  ) {
    self.value = value
    self.context = context
    self.autosave = autosave
    self.transaction = transaction
  }

  /// Inserts a model into the current `ModelContext`.
  public func append(_ model: Element) throws {
    try _performThrowsWritableMutation(
      context: context,
      autosave: autosave,
      transaction: transaction,
      models: [model]
    ) {
      context.insert(model)
    }
  }

  /// Inserts a model into the current `ModelContext`.
  public func insert(_ model: Element) throws {
    try append(model)
  }

  /// Inserts each model in the sequence into the current `ModelContext`.
  public func append<S: Sequence>(contentsOf models: S) throws where S.Element == Element {
    let insertedModels = Array(models)
    try _performThrowsWritableMutation(
      context: context,
      autosave: autosave,
      transaction: transaction,
      models: insertedModels
    ) {
      for model in insertedModels {
        context.insert(model)
      }
    }
  }

  /// Deletes a model from the current `ModelContext`.
  public func delete(_ model: Element) throws {
    try _performThrowsWritableMutation(
      context: context,
      autosave: autosave,
      transaction: transaction,
      models: [model]
    ) {
      context.delete(model)
    }
  }

  /// Deletes every model in the current query snapshot.
  public func deleteAll() throws {
    let deletedModels = Array(value)
    try _performThrowsWritableMutation(
      context: context,
      autosave: autosave,
      transaction: transaction,
      models: deletedModels
    ) {
      for model in deletedModels {
        context.delete(model)
      }
    }
  }

  /// Saves the underlying `ModelContext`.
  public func save() throws {
    try context.save()
  }

  /// Runs a write closure against the underlying `ModelContext`.
  public func write(_ body: (ModelContext) throws -> Void) throws {
    try _performThrowsWritableMutation(
      context: context,
      autosave: autosave,
      transaction: transaction,
      models: Array(value)
    ) {
      try body(context)
    }
  }

  /// Runs a write closure with the current query snapshot and underlying context.
  @discardableResult
  public func write<Result>(
    _ body: (Base, ModelContext) throws -> Result
  ) throws -> Result {
    try _performThrowsWritableMutation(
      context: context,
      autosave: autosave,
      transaction: transaction,
      models: Array(value)
    ) {
      try body(value, context)
    }
  }
}
