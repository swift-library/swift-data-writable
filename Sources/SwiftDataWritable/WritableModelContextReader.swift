import SwiftData
import SwiftUI

/// Implementation detail used by `@Writable` macro expansion.
@MainActor
public struct _WritableModelContextReader: DynamicProperty {
  @SwiftUI.Environment(\.modelContext)
  private var modelContext: ModelContext

  public init() {}

  public var context: ModelContext {
    modelContext
  }
}
