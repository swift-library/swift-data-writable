import SwiftData
import SwiftUI

/// Errors raised when bridging SwiftUI `Bindable` values into writable projections.
public enum WritableModelError: Error, Equatable, Sendable {
  /// The model is not currently attached to a SwiftData `ModelContext`.
  case detachedModel
}

@MainActor
public extension Bindable where Value: PersistentModel {
  /// A writable projection for the bound model.
  var writable: WritableModel<Value> {
    get throws {
      try writable()
    }
  }

  /// A writable projection for the bound model.
  func writable(
    autosave: Bool = false,
    transaction: WritableTransaction<Value>? = nil
  ) throws -> WritableModel<Value> {
    try WritableModel(
      value: wrappedValue,
      context: attachedModelContext(),
      autosave: autosave,
      transaction: transaction
    )
  }

  /// An error-transparent writable projection for the bound model.
  var throwsWritable: ThrowsWritableModel<Value> {
    get throws {
      try throwsWritable()
    }
  }

  /// An error-transparent writable projection for the bound model.
  func throwsWritable(
    autosave: Bool = false,
    transaction: WritableTransaction<Value>? = nil
  ) throws -> ThrowsWritableModel<Value> {
    try ThrowsWritableModel(
      value: wrappedValue,
      context: attachedModelContext(),
      autosave: autosave,
      transaction: transaction
    )
  }

  private func attachedModelContext() throws -> ModelContext {
    guard let context = wrappedValue.modelContext else {
      throw WritableModelError.detachedModel
    }

    return context
  }
}
