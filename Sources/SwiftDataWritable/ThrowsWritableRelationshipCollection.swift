// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import SwiftData

/// Error-transparent write actions for a relationship collection rooted at a model.
///
/// `ThrowsWritableRelationshipCollection` mirrors
/// `WritableRelationshipCollection`, but autosave failures are thrown to the
/// caller.
// The write overloads differ by closure arity within this type.
// swift-format-ignore: AmbiguousTrailingClosureOverload
public struct ThrowsWritableRelationshipCollection<Root, Base>
where
  Root: PersistentModel,
  Base: RandomAccessCollection,
  Base: RangeReplaceableCollection,
  Base.Element: PersistentModel
{
  /// The model type contained in the relationship collection.
  public typealias Element = Base.Element

  /// The model at the root of the relationship collection key path.
  public let root: Root
  /// The writable key path from the root model to the relationship collection.
  public let keyPath: ReferenceWritableKeyPath<Root, Base>
  /// The SwiftData context used for saves and writes.
  public let context: ModelContext
  /// Whether mutation operations should save after mutation.
  public let autosave: Bool
  /// Optional root autosave transaction hook.
  public let transaction: WritableTransaction<Root>?

  /// The current relationship collection value.
  public var value: Base {
    root[keyPath: keyPath]
  }

  /// Creates an error-transparent writable projection for a root relationship collection.
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
  public func append(_ model: Element) throws {
    try update { relationship in
      relationship.append(model)
    }
  }

  /// Appends each model to the owner relationship collection.
  public func append<S: Sequence>(contentsOf models: S) throws where S.Element == Element {
    try update { relationship in
      relationship.append(contentsOf: models)
    }
  }

  /// Removes matching models from the owner relationship collection.
  public func remove(_ model: Element) throws {
    try update { relationship in
      relationship.removeAll { candidate in
        candidate.persistentModelID == model.persistentModelID
      }
    }
  }

  /// Removes every model from the owner relationship collection.
  public func removeAll() throws {
    try update { relationship in
      relationship.removeAll()
    }
  }

  /// Removes models at offsets in the current relationship collection.
  public func remove(atOffsets offsets: IndexSet) throws {
    try update { relationship in
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

  /// Returns an error-transparent writable projection for a model in the relationship collection.
  public subscript(position: Base.Index) -> ThrowsWritableModel<Element> {
    ThrowsWritableModel(
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
    try _performThrowsWritableMutation(
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
    try _performThrowsWritableMutation(
      context: context,
      autosave: autosave,
      transaction: transaction,
      value: root
    ) {
      try body(value, context)
    }
  }

  private func update(_ body: (inout Base) -> Void) throws {
    try _performThrowsWritableMutation(
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
