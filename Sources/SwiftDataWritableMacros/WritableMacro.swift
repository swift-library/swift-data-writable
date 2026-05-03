import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct WritableMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard
      let property = WritablePropertyParser.parse(
        declaration: declaration,
        context: context
      )
    else {
      return []
    }

    let contextName = context.makeUniqueName("_\(property.name)WritableContext").text
    let access = property.accessModifier.isEmpty ? "" : "\(property.accessModifier) "
    let projectionName = "$\(property.name)"

    guard let autosave = node.autosave(context: context) else {
      return []
    }
    guard let throwsSaveErrors = node.throwsSaveErrors(context: context) else {
      return []
    }

    if case .bindableModel = property.kind {
      if node.isMutableWritable {
        context.diagnose(.mutableByCollectionOnly, at: node)
      }
      return []
    }

    if case .singleModel = property.kind, node.isMutableWritable {
      context.diagnose(.mutableByCollectionOnly, at: node)
      return []
    }

    let contextDeclaration: DeclSyntax =
      """
      private var \(raw: contextName) = SwiftDataWritable._WritableModelContextReader()
      """

    switch property.kind {
    case .bindableModel:
      return []
    case .singleModel(let modelType, false):
      let projectionType = throwsSaveErrors ? "ThrowsWritableModel" : "WritableModel"
      let projection: DeclSyntax =
        """
        \(raw: access)var `\(raw: projectionName)`: SwiftDataWritable.\(raw: projectionType)<\(raw: modelType)> {
            SwiftDataWritable.\(raw: projectionType)(
                value: \(raw: property.name),
                context: \(raw: contextName).context,
                autosave: \(raw: autosave ? "true" : "false")
            )
        }
        """

      return [contextDeclaration, projection]
    case .singleModel(let modelType, true):
      let projectionType = throwsSaveErrors ? "ThrowsWritableModel" : "WritableModel"
      let projection: DeclSyntax =
        """
        \(raw: access)var `\(raw: projectionName)`: SwiftDataWritable.\(raw: projectionType)<\(raw: modelType)>? {
            guard let model = \(raw: property.name) else {
                return nil
            }

            return SwiftDataWritable.\(raw: projectionType)(
                value: model,
                context: \(raw: contextName).context,
                autosave: \(raw: autosave ? "true" : "false")
            )
        }
        """

      return [contextDeclaration, projection]
    case .queryCollection(let elementType):
      if node.isMutableWritable, node.mutableByExpression == nil {
        context.diagnose(.mutableByKeyPath, at: node)
        return []
      }

      let collectionType = "[\(elementType)]"

      guard let mutableByExpression = node.mutableByExpression else {
        let projectionType = throwsSaveErrors ? "ThrowsWritableModelCollection" : "WritableModelCollection"
        let projection: DeclSyntax =
          """
          \(raw: access)var `\(raw: projectionName)`: SwiftDataWritable.\(raw: projectionType)<\(raw: collectionType)> {
              SwiftDataWritable.\(raw: projectionType)(
                  value: \(raw: property.name),
                  context: \(raw: contextName).context,
                  autosave: \(raw: autosave ? "true" : "false")
              )
          }
          """

        return [contextDeclaration, projection]
      }

      let projectionType = throwsSaveErrors
        ? "KeyPathThrowsWritableModelCollection"
        : "KeyPathWritableModelCollection"
      let projection: DeclSyntax =
        """
        \(raw: access)var `\(raw: projectionName)`: SwiftDataWritable.\(raw: projectionType)<\(raw: collectionType)> {
            SwiftDataWritable.\(raw: projectionType)(
                value: \(raw: property.name),
                context: \(raw: contextName).context,
                autosave: \(raw: autosave ? "true" : "false"),
                mutableBy: \(mutableByExpression)
            )
        }
        """

      return [contextDeclaration, projection]
    }
  }
}

extension AttributeSyntax {
  fileprivate var mutableByExpression: ExprSyntax? {
    guard case .argumentList(let arguments) = arguments else {
      return nil
    }

    return arguments.first { argument in
      argument.label?.text == "mutableBy"
    }?.expression
  }

  fileprivate var isMutableWritable: Bool {
    guard case .argumentList(let arguments) = arguments else {
      return false
    }

    return arguments.contains { argument in
      argument.label?.text == "mutableBy"
    }
  }

  fileprivate func autosave(context: some MacroExpansionContext) -> Bool? {
    guard case .argumentList(let arguments) = arguments else {
      return false
    }

    guard
      let argument = arguments.first(where: { argument in
        argument.label?.text == "autosave"
      })
    else {
      return false
    }

    switch argument.expression.trimmedDescription {
    case "true":
      return true
    case "false":
      return false
    default:
      context.diagnose(.autosaveLiteral, at: argument.expression)
      return nil
    }
  }

  fileprivate func throwsSaveErrors(context: some MacroExpansionContext) -> Bool? {
    guard case .argumentList(let arguments) = arguments else {
      return false
    }

    guard
      let argument = arguments.first(where: { argument in
        argument.label?.text == "throws"
      })
    else {
      return false
    }

    switch argument.expression.trimmedDescription {
    case "true":
      return true
    case "false":
      return false
    default:
      context.diagnose(.throwsLiteral, at: argument.expression)
      return nil
    }
  }
}

@main
struct SwiftDataWritablePlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    WritableMacro.self
  ]
}
