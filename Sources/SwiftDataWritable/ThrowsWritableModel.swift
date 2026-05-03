import SwiftData

/// Error-transparent write actions for a single SwiftData model.
///
/// `ThrowsWritableModel` mirrors `WritableModel`, but autosave failures are
/// thrown to the caller.
@MainActor
@dynamicMemberLookup
public struct ThrowsWritableModel<Model: PersistentModel> {
  /// The projected model type.
  public typealias Element = Model

  /// The current model passed to the projection.
  public let value: Model
  /// The SwiftData context used for saves and writes.
  public let context: ModelContext
  /// Whether mutation operations should save after mutation.
  public let autosave: Bool
  /// Optional autosave transaction hook.
  public let transaction: WritableTransaction<Model>?

  /// Creates an error-transparent writable projection for a model.
  public init(
    value: Model,
    context: ModelContext,
    autosave: Bool = false,
    transaction: WritableTransaction<Model>? = nil
  ) {
    self.value = value
    self.context = context
    self.autosave = autosave
    self.transaction = transaction
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
      models: [value]
    ) {
      try body(context)
    }
  }

  /// Runs a write closure with the projected model and underlying context.
  @discardableResult
  public func write<Result>(
    _ body: (Model, ModelContext) throws -> Result
  ) throws -> Result {
    try _performThrowsWritableMutation(
      context: context,
      autosave: autosave,
      transaction: transaction,
      models: [value]
    ) {
      try body(value, context)
    }
  }

  /// Returns an error-transparent writable projection for a relationship collection on the model.
  public subscript<Base>(
    dynamicMember keyPath: ReferenceWritableKeyPath<Model, Base>
  ) -> ThrowsWritableRelationshipCollection<Model, Base>
  where Base: RandomAccessCollection,
        Base: RangeReplaceableCollection,
        Base.Element: PersistentModel {
    ThrowsWritableRelationshipCollection(
      root: value,
      keyPath: keyPath,
      context: context,
      autosave: autosave,
      transaction: transaction
    )
  }

  /// Returns an error-transparent writable projection for a single relationship.
  public subscript<Child>(
    dynamicMember keyPath: KeyPath<Model, Child>
  ) -> ThrowsWritableModel<Child>
  where Child: PersistentModel {
    ThrowsWritableModel<Child>(
      value: value[keyPath: keyPath],
      context: context,
      autosave: autosave,
      transaction: transaction?.wrapping(root: value)
    )
  }

  /// Returns an error-transparent writable projection for an optional single relationship.
  public subscript<Child>(
    dynamicMember keyPath: KeyPath<Model, Child?>
  ) -> ThrowsWritableModel<Child>?
  where Child: PersistentModel {
    guard let child = value[keyPath: keyPath] else {
      return nil
    }

    return ThrowsWritableModel<Child>(
      value: child,
      context: context,
      autosave: autosave,
      transaction: transaction?.wrapping(root: value)
    )
  }
}
