import Foundation
import SwiftData
import SwiftUI

/// Write actions for a SwiftData query collection with persisted reordering.
///
/// `KeyPathWritableModelCollection` is produced by `@Writable(mutableBy:)`. It
/// exposes the same mutation actions as `WritableModelCollection` plus `move`,
/// which rewrites a comparable reference-writable key path using the current
/// query snapshot's existing ordering values.
@MainActor
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

  private let rewriteValues: ([Element], [Element]) -> Void

  /// Creates a writable reorder projection for a query snapshot.
  ///
  /// - Parameters:
  ///   - value: The current query snapshot.
  ///   - context: The current SwiftData `ModelContext`.
  ///   - autosave: Whether mutation operations should attempt a best-effort save.
  ///   - keyPath: A reference-writable key path whose current values define
  ///     the persisted order.
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
  public func append(_ model: Element) {
    context.insert(model)
    _autosave()
  }

  /// Inserts a model into the current `ModelContext`.
  public func insert(_ model: Element) {
    context.insert(model)
    _autosave()
  }

  /// Inserts each model in the sequence into the current `ModelContext`.
  public func append<S: Sequence>(contentsOf models: S) where S.Element == Element {
    for model in models {
      context.insert(model)
    }
    _autosave()
  }

  /// Deletes a model from the current `ModelContext`.
  public func delete(_ model: Element) {
    context.delete(model)
    _autosave()
  }

  /// Deletes every model in the current query snapshot.
  public func deleteAll() {
    for model in value {
      context.delete(model)
    }
    _autosave()
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
    for offset in offsets.sorted(by: >) {
      guard
        let index = value.index(value.startIndex, offsetBy: offset, limitedBy: value.endIndex),
        index != value.endIndex
      else {
        continue
      }

      context.delete(value[index])
    }

    _autosave()
  }

  /// Reorders the current snapshot and rewrites the ordering key path values.
  ///
  /// The implementation preserves the existing comparable values from the
  /// original snapshot and reassigns them to the moved models. It does not
  /// synthesize dense integer order values.
  public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
    guard reorder(fromOffsets: source, toOffset: destination) else {
      return
    }

    _autosave()
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
  public func write(_ body: (ModelContext) throws -> Void) rethrows {
    try body(context)
    _autosave()
  }

  /// Runs a write closure with the current query snapshot and underlying context.
  @discardableResult
  public func write<Result>(
    _ body: (Base, ModelContext) throws -> Result
  ) rethrows -> Result {
    let result = try body(value, context)
    _autosave()
    return result
  }

  private func _autosave() {
    guard autosave else {
      return
    }

    try? context.save()
  }
}
