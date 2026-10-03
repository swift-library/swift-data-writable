// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import SwiftData
import SwiftUI

/// Write actions for a SwiftData query collection with persisted reordering.
///
/// `KeyPathWritableModelCollection` is produced by `@Writable(mutableBy:)`. It
/// exposes the same mutation actions as `WritableModelCollection` plus `move`,
/// which rewrites a comparable reference-writable key path using the current
/// query snapshot's existing ordering values.
// The write overloads differ by closure arity within this type.
// swift-format-ignore: AmbiguousTrailingClosureOverload
public struct KeyPathWritableModelCollection<Base: RandomAccessCollection>
where Base.Element: PersistentModel {
  /// The model type contained in the query collection.
  public typealias Element = Base.Element

  /// The current query snapshot passed to the projection.
  public let value: Base
  /// The SwiftData context used for inserts, deletes, saves, and writes.
  public let context: ModelContext
  /// Whether mutation operations should attempt a best-effort save.
  public let autosave: Bool
  /// Optional autosave transaction hook for affected collection values.
  public let transaction: WritableTransaction<[Element]>?

  private let rewriteValues: ([Element], [Element]) -> Void

  /// Creates a writable reorder projection for a query snapshot.
  ///
  /// - Parameters:
  ///   - value: The current query snapshot.
  ///   - context: The current SwiftData `ModelContext`.
  ///   - autosave: Whether mutation operations should attempt a best-effort save.
  ///   - transaction: Optional autosave hook for the affected collection values.
  ///   - keyPath: A reference-writable key path whose current values define
  ///     the persisted order.
  public init<Value: Comparable>(
    value: Base,
    context: ModelContext,
    autosave: Bool = false,
    transaction: WritableTransaction<[Element]>? = nil,
    mutableBy keyPath: ReferenceWritableKeyPath<Element, Value>
  ) {
    self.value = value
    self.context = context
    self.autosave = autosave
    self.transaction = transaction
    self.rewriteValues = { originalModels, movedModels in
      let values = originalModels.map { $0[keyPath: keyPath] }

      for (model, value) in zip(movedModels, values) {
        model[keyPath: keyPath] = value
      }
    }
  }

  /// Inserts a model into the current `ModelContext`.
  public func append(_ model: Element) {
    try? _performWritableMutation(
      context: context,
      autosave: autosave,
      transaction: transaction,
      value: [model]
    ) {
      context.insert(model)
    }
  }

  /// Inserts a model into the current `ModelContext`.
  public func insert(_ model: Element) {
    append(model)
  }

  /// Inserts each model in the sequence into the current `ModelContext`.
  public func append<S: Sequence>(contentsOf models: S) where S.Element == Element {
    let insertedModels = Array(models)
    try? _performWritableMutation(
      context: context,
      autosave: autosave,
      transaction: transaction,
      value: insertedModels
    ) {
      for model in insertedModels {
        context.insert(model)
      }
    }
  }

  /// Deletes a model from the current `ModelContext`.
  public func delete(_ model: Element) {
    try? _performWritableMutation(
      context: context,
      autosave: autosave,
      transaction: transaction,
      value: [model]
    ) {
      context.delete(model)
    }
  }

  /// Deletes every model in the current query snapshot.
  public func deleteAll() {
    let deletedModels = Array(value)
    try? _performWritableMutation(
      context: context,
      autosave: autosave,
      transaction: transaction,
      value: deletedModels
    ) {
      for model in deletedModels {
        context.delete(model)
      }
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

  /// Deletes models at offsets in the current query snapshot.
  public func remove(atOffsets offsets: IndexSet) {
    let models = offsets.sorted(by: >).compactMap { offset -> Element? in
      guard
        let index = value.index(
          value.startIndex,
          offsetBy: offset,
          limitedBy: value.endIndex
        ),
        index != value.endIndex
      else {
        return nil
      }

      return value[index]
    }

    try? _performWritableMutation(
      context: context,
      autosave: autosave,
      transaction: transaction,
      value: models
    ) {
      for model in models {
        context.delete(model)
      }
    }
  }

  /// Reorders the current snapshot and rewrites the ordering key path values.
  ///
  /// The implementation preserves the existing comparable values from the
  /// original snapshot and reassigns them to the moved models. It does not
  /// synthesize dense integer order values.
  public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
    try? _performWritableMutation(
      context: context,
      autosave: autosave,
      transaction: transaction,
      value: Array(value)
    ) {
      _ = reorder(fromOffsets: source, toOffset: destination)
    }
  }

  @discardableResult
  fileprivate func reorder(fromOffsets source: IndexSet, toOffset destination: Int) -> Bool {
    let originalModels = Array(value)
    var movedModels = originalModels
    var validSource = IndexSet()

    for offset in source where movedModels.indices.contains(offset) {
      validSource.insert(offset)
    }

    guard !validSource.isEmpty else {
      return false
    }

    let boundedDestination = max(0, min(destination, movedModels.count))
    movedModels.move(fromOffsets: validSource, toOffset: boundedDestination)
    rewriteValues(originalModels, movedModels)
    return true
  }

  /// Returns a writable projection for a model in the current query snapshot.
  public subscript(position: Base.Index) -> WritableModel<Element> {
    WritableModel(
      value: value[position],
      context: context,
      autosave: autosave,
      transaction: transaction?.wrapping(root: [value[position]])
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
      value: Array(value)
    ) {
      try body(context)
    }
  }

  /// Runs a write closure with the current query snapshot and underlying context.
  @discardableResult
  public func write<Result>(
    _ body: (Base, ModelContext) throws -> Result
  ) throws -> Result {
    try _performWritableMutation(
      context: context,
      autosave: autosave,
      transaction: transaction,
      value: Array(value)
    ) {
      try body(value, context)
    }
  }
}
