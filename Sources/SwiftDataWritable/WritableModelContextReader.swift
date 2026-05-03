import SwiftData
import SwiftUI
import _SwiftData_SwiftUI

/// Implementation detail used by `@Writable` macro expansion.
@MainActor
public struct _WritableModelContextReader: DynamicProperty {
  @Environment(\EnvironmentValues.modelContext)
  private var modelContext: ModelContext

  public init() {}

  public var context: ModelContext {
    modelContext
  }
}
