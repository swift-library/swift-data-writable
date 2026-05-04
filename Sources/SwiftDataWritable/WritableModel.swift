import SwiftData

/// Write actions for a single SwiftData model.
///
/// `WritableModel` is produced by `@Writable` as a `$property` companion for a
/// single model property. It does not define domain-specific actions such as
/// rename or move; downstream packages can extend it for those commands.
@dynamicMemberLookup
public struct WritableModel<Model: PersistentModel> {
  /// The projected model type.
  public typealias Element = Model

  /// The current model passed to the projection.
  public let value: Model
  /// The SwiftData context used for saves and writes.
  public let context: ModelContext
  /// Whether mutation operations should attempt a best-effort save.
  public let autosave: Bool
  /// Optional autosave transaction hook.
  public let transaction: WritableTransaction<Model>?

  /// Creates a writable projection for a model.
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
    try _performWritableMutation(
      context: context,
      autosave: autosave,
      transaction: transaction,
      value: value
    ) {
      try body(context)
    }
  }

  /// Runs a write closure with the projected model and underlying context.
  @discardableResult
  public func write<Result>(
    _ body: (Model, ModelContext) throws -> Result
  ) throws -> Result {
    try _performWritableMutation(
      context: context,
      autosave: autosave,
      transaction: transaction,
      value: value
    ) {
      try body(value, context)
    }
  }

  /// Returns a writable projection for a relationship collection on the model.
  public subscript<Base>(
    dynamicMember keyPath: ReferenceWritableKeyPath<Model, Base>
  ) -> WritableRelationshipCollection<Model, Base>
  where Base: RandomAccessCollection,
        Base: RangeReplaceableCollection,
        Base.Element: PersistentModel {
    WritableRelationshipCollection(
      root: value,
      keyPath: keyPath,
      context: context,
      autosave: autosave,
      transaction: transaction
    )
  }

  /// Returns a writable projection for a single relationship on the model.
  public subscript<Child>(
    dynamicMember keyPath: KeyPath<Model, Child>
  ) -> WritableModel<Child>
  where Child: PersistentModel {
    WritableModel<Child>(
      value: value[keyPath: keyPath],
      context: context,
      autosave: autosave,
      transaction: transaction?.wrapping(root: value)
    )
  }

  /// Returns a writable projection for an optional single relationship.
  public subscript<Child>(
    dynamicMember keyPath: KeyPath<Model, Child?>
  ) -> WritableModel<Child>?
  where Child: PersistentModel {
    guard let child = value[keyPath: keyPath] else {
      return nil
    }

    return WritableModel<Child>(
      value: child,
      context: context,
      autosave: autosave,
      transaction: transaction?.wrapping(root: value)
    )
  }
}
