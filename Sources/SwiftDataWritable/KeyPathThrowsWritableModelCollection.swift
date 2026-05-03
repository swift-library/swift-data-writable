import Foundation
import SwiftData
import SwiftUI

/// Error-transparent write actions for a SwiftData query collection with persisted reordering.
///
/// `KeyPathThrowsWritableModelCollection` mirrors
/// `KeyPathWritableModelCollection`, but autosave failures are thrown to the
/// caller.
@MainActor
public struct KeyPathThrowsWritableModelCollection<Base: RandomAccessCollection>
where Base.Element: PersistentModel {
  /// The model type contained in the query collection.
  public typealias Element = Base.Element

  /// The current query snapshot passed to the projection.
  public let value: Base
  /// The SwiftData context used for inserts, deletes, saves, and writes.
  public let context: ModelContext
  /// Whether mutation operations should save after mutation.
  public let autosave: Bool

  private let rewriteValues: ([Element], [Element]) -> Void

  /// Creates an error-transparent writable reorder projection for a query snapshot.
  public init<Value: Comparable>(
    value: Base,
    context: ModelContext,
    autosave: Bool = false,
    mutableBy keyPath: ReferenceWritableKeyPath<Element, Value>
  ) {
    self.value = value
    self.context = context
    self.autosave = autosave
    self.rewriteValues = { originalModels, movedModels in
      let values = originalModels.map { $0[keyPath: keyPath] }

      for (model, value) in zip(movedModels, values) {
        model[keyPath: keyPath] = value
      }
    }
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

  /// Deletes models at offsets in the current query snapshot.
  public func remove(atOffsets offsets: IndexSet) throws {
    for offset in offsets.sorted(by: >) {
      guard
        let index = value.index(value.startIndex, offsetBy: offset, limitedBy: value.endIndex),
        index != value.endIndex
      else {
        continue
      }

      context.delete(value[index])
    }

    try _autosave()
  }

  /// Reorders the current snapshot, rewrites ordering key path values, and autosaves if requested.
  public func move(fromOffsets source: IndexSet, toOffset destination: Int) throws {
    guard reorder(fromOffsets: source, toOffset: destination) else {
      return
    }

    try _autosave()
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
