import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

enum WritableDiagnostic: String, DiagnosticMessage {
  case queryBackedCollection
  case explicitCollectionType
  case explicitModelType
  case supportedCollectionType
  case supportedModelType
  case relationshipUnsupported
  case attributeUnsupported
  case transientUnsupported
  case bindableQueryUnsupported
  case bindableModelUnsupported
  case mutableByKeyPath
  case mutableByCollectionOnly
  case autosaveLiteral
  case throwsLiteral

  var message: String {
    switch self {
    case .queryBackedCollection:
      return "@Writable collections require a @Query-backed array property."
    case .explicitCollectionType:
      return
        "@Writable requires an explicit collection type annotation, for example: private var persons: [Person]."
    case .explicitModelType:
      return
        "@Writable requires an explicit model type annotation, for example: private var person: Person."
    case .supportedCollectionType:
      return "@Writable supports [Model] or Array<Model> query results."
    case .supportedModelType:
      return "@Writable supports model properties, optional model properties, or @Query-backed array results."
    case .relationshipUnsupported:
      return
        "@Writable is not for @Relationship fields. Project relationships from a writable owner model or use domain methods instead."
    case .attributeUnsupported:
      return
        "@Writable is not for @Attribute fields. Use it with query collections or model properties instead."
    case .transientUnsupported:
      return
        "@Writable is not for @Transient fields. Use it with query collections or model properties instead."
    case .bindableQueryUnsupported:
      return "@Writable @Bindable cannot be combined with @Query."
    case .bindableModelUnsupported:
      return "@Writable @Bindable supports non-optional model properties only."
    case .mutableByKeyPath:
      return "@Writable(mutableBy:) requires a writable key path to a Comparable ordering field."
    case .mutableByCollectionOnly:
      return "@Writable(mutableBy:) can only be used with @Query-backed collection properties."
    case .autosaveLiteral:
      return "@Writable(autosave:) requires a literal true or false value."
    case .throwsLiteral:
      return "@Writable(throws:) requires a literal true or false value."
    }
  }

  var diagnosticID: MessageID {
    MessageID(domain: "SwiftDataWritable.Writable", id: rawValue)
  }

  var severity: DiagnosticSeverity {
    .error
  }
}

extension MacroExpansionContext {
  func diagnose(_ diagnostic: WritableDiagnostic, at node: some SyntaxProtocol) {
    diagnose(Diagnostic(node: Syntax(node), message: diagnostic))
  }
}
