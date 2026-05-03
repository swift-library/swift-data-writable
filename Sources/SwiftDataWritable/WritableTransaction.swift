import SwiftData

/// A typed around-mutation hook used by writable projections during autosave.
///
/// `WritableTransaction` is invoked only when a projection has `autosave`
/// enabled. The transaction receives the active context, the models directly
/// affected by the projection, and a mutation closure. Domain packages can use
/// this hook to wrap writable mutations in their own save/writeback policy.
@MainActor
public struct WritableTransaction<Model: PersistentModel> {
  private let perform: @MainActor (
    _ context: ModelContext,
    _ models: [Model],
    _ mutation: () throws -> Void
  ) throws -> Void

  /// Creates a writable transaction hook.
  public init(
    _ perform: @escaping @MainActor (
      _ context: ModelContext,
      _ models: [Model],
      _ mutation: () throws -> Void
    ) throws -> Void
  ) {
    self.perform = perform
  }

  /// Executes the transaction hook.
  public func callAsFunction(
    context: ModelContext,
    models: [Model],
    _ mutation: () throws -> Void
  ) throws {
    try perform(context, models, mutation)
  }

  func wrapping<Child: PersistentModel>(
    root: Model
  ) -> WritableTransaction<Child> {
    WritableTransaction<Child> { context, _, mutation in
      try self(context: context, models: [root]) {
        try mutation()
      }
    }
  }
}

@MainActor
func _performWritableMutation<Model: PersistentModel, Result>(
  context: ModelContext,
  autosave: Bool,
  transaction: WritableTransaction<Model>?,
  models: [Model],
  _ mutation: () throws -> Result
) throws -> Result {
  guard autosave else {
    return try mutation()
  }

  guard let transaction else {
    let result = try mutation()
    try? context.save()
    return result
  }

  let output = _WritableTransactionOutputBox<Result>()
  do {
    try transaction(context: context, models: models) {
      output.set(try mutation())
    }
  } catch {
    if output.hasValue {
      return output.requiredValue
    }

    throw error
  }

  return output.requiredValue
}

@MainActor
func _performThrowsWritableMutation<Model: PersistentModel, Result>(
  context: ModelContext,
  autosave: Bool,
  transaction: WritableTransaction<Model>?,
  models: [Model],
  _ mutation: () throws -> Result
) throws -> Result {
  guard autosave else {
    return try mutation()
  }

  guard let transaction else {
    let result = try mutation()
    try context.save()
    return result
  }

  let output = _WritableTransactionOutputBox<Result>()
  try transaction(context: context, models: models) {
    output.set(try mutation())
  }
  return output.requiredValue
}

private final class _WritableTransactionOutputBox<Output> {
  private enum Storage {
    case empty
    case value(Output)
  }

  private var storage = Storage.empty

  var hasValue: Bool {
    if case .value = storage {
      return true
    }

    return false
  }

  func set(_ output: Output) {
    storage = .value(output)
  }

  var requiredValue: Output {
    guard case .value(let output) = storage else {
      preconditionFailure("WritableTransaction must invoke its mutation closure.")
    }

    return output
  }
}
