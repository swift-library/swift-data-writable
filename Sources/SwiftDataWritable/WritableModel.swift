import SwiftData

/// Write actions for a single SwiftData model.
///
/// `WritableModel` is produced by `@Writable` as a `$property` companion for a
/// single model property. It does not define domain-specific actions such as
/// rename or move; downstream packages can extend it for those commands.
@MainActor
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

  /// Creates a writable projection for a model.
  public init(value: Model, context: ModelContext, autosave: Bool = false) {
    self.value = value
    self.context = context
    self.autosave = autosave
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

  /// Runs a write closure with the projected model and underlying context.
  @discardableResult
  public func write<Result>(
    _ body: (Model, ModelContext) throws -> Result
  ) rethrows -> Result {
    let result = try body(value, context)
    _autosave()
    return result
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
      autosave: autosave
    )
  }

  private func _autosave() {
    guard autosave else {
      return
    }

    try? context.save()
  }
}
