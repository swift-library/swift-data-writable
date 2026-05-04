import Foundation
import SwiftData

/// Write actions for a relationship collection rooted at a model.
///
/// `WritableRelationshipCollection` is produced by dynamic member lookup from
/// `WritableModel`. It mutates the owner's relationship collection directly; it
/// does not represent a SwiftData `@Query` snapshot.
@MainActor
public struct WritableRelationshipCollection<Root, Base>
where Root: PersistentModel,
      Base: RandomAccessCollection,
      Base: RangeReplaceableCollection,
      Base.Element: PersistentModel {
  /// The model type contained in the relationship collection.
  public typealias Element = Base.Element

  /// The model at the root of the relationship collection key path.
  public let root: Root
  /// The writable key path from the root model to the relationship collection.
  public let keyPath: ReferenceWritableKeyPath<Root, Base>
  /// The SwiftData context used for saves and writes.
  public let context: ModelContext
  /// Whether mutation operations should attempt a best-effort save.
  public let autosave: Bool
  /// Optional root autosave transaction hook.
  public let transaction: WritableTransaction<Root>?

  /// The current relationship collection value.
  public var value: Base {
    root[keyPath: keyPath]
  }

  /// Creates a writable projection for a root relationship collection.
  public init(
    root: Root,
    keyPath: ReferenceWritableKeyPath<Root, Base>,
    context: ModelContext,
    autosave: Bool = false,
    transaction: WritableTransaction<Root>? = nil
  ) {
    self.root = root
    self.keyPath = keyPath
    self.context = context
    self.autosave = autosave
    self.transaction = transaction
  }

  /// Appends a model to the owner relationship collection.
  public func append(_ model: Element) {
    update { relationship in
      relationship.append(model)
    }
  }

  /// Appends each model to the owner relationship collection.
  public func append<S: Sequence>(contentsOf models: S) where S.Element == Element {
    update { relationship in
      relationship.append(contentsOf: models)
    }
  }

  /// Removes matching models from the owner relationship collection.
  public func remove(_ model: Element) {
    update { relationship in
      relationship.removeAll { candidate in
        candidate.persistentModelID == model.persistentModelID
      }
    }
  }

  /// Removes every model from the owner relationship collection.
  public func removeAll() {
    update { relationship in
      relationship.removeAll()
    }
  }

  /// A function value compatible with SwiftUI `.onDelete(perform:)`.
  ///
  /// This preserves `$items.remove` call sites while keeping
  /// `remove(atOffsets:)` as the labeled operation.
  public var remove: (IndexSet) -> Void {
    { offsets in
      remove(atOffsets: offsets)
    }
  }

  /// Removes models at offsets in the current relationship collection.
  public func remove(atOffsets offsets: IndexSet) {
    update { relationship in
      for offset in offsets.sorted(by: >) {
        guard
          let index = relationship.index(
            relationship.startIndex,
            offsetBy: offset,
            limitedBy: relationship.endIndex
          ),
          index != relationship.endIndex
        else {
          continue
        }

        relationship.remove(at: index)
      }
    }
  }

  /// Returns a writable projection for a model in the relationship collection.
  public subscript(position: Base.Index) -> WritableModel<Element> {
    WritableModel(
      value: value[position],
      context: context,
      autosave: autosave,
      transaction: transaction?.wrapping(root: root)
    )
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
      value: root
    ) {
      try body(context)
    }
  }

  /// Runs a write closure with the current relationship collection and context.
  @discardableResult
  public func write<Result>(
    _ body: (Base, ModelContext) throws -> Result
  ) throws -> Result {
    try _performWritableMutation(
      context: context,
      autosave: autosave,
      transaction: transaction,
      value: root
    ) {
      try body(value, context)
    }
  }

  private func update(_ body: (inout Base) -> Void) {
    try? _performWritableMutation(
      context: context,
      autosave: autosave,
      transaction: transaction,
      value: root
    ) {
      var relationship = root[keyPath: keyPath]
      body(&relationship)
      root[keyPath: keyPath] = relationship
    }
  }
}
