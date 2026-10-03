// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import SwiftData

/// Write actions for a SwiftData query collection.
///
/// `WritableModelCollection` is usually produced by `@Writable` as a
/// `$property` companion for an existing `@Query` array. It mutates the current
/// `ModelContext`; when `autosave` is enabled, automatic save failures are
/// swallowed. Call `save()` when the caller needs explicit error handling.
// The write overloads differ by closure arity within this type.
// swift-format-ignore: AmbiguousTrailingClosureOverload
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
  /// Optional autosave transaction hook for affected collection values.
  public let transaction: WritableTransaction<[Element]>?

  /// Creates a writable surface for a query snapshot.
  public init(
    value: Base,
    context: ModelContext,
    autosave: Bool = false,
    transaction: WritableTransaction<[Element]>? = nil
  ) {
    self.value = value
    self.context = context
    self.autosave = autosave
    self.transaction = transaction
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
