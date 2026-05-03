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

  /// Creates an error-transparent writable projection for a model.
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
  public func write(_ body: (ModelContext) throws -> Void) throws {
    try body(context)
    try _autosave()
  }

  /// Runs a write closure with the projected model and underlying context.
  @discardableResult
  public func write<Result>(
    _ body: (Model, ModelContext) throws -> Result
  ) throws -> Result {
    let result = try body(value, context)
    try _autosave()
    return result
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
      autosave: autosave
    )
  }

  private func _autosave() throws {
    guard autosave else {
      return
    }

    try context.save()
  }
}
