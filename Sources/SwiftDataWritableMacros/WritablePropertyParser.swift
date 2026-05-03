import SwiftSyntax
import SwiftSyntaxMacros

struct WritableProperty {
  let name: String
  let kind: WritablePropertyKind
  let accessModifier: String
}

enum WritablePropertyKind {
  case queryCollection(elementType: String)
  case singleModel(modelType: String, isOptional: Bool)
  case bindableModel
}

enum WritablePropertyParser {
  static func parse(
    declaration: some DeclSyntaxProtocol,
    context: some MacroExpansionContext
  ) -> WritableProperty? {
    guard let variable = declaration.as(VariableDeclSyntax.self) else {
      context.diagnose(.queryBackedCollection, at: declaration)
      return nil
    }

    if variable.hasAttribute(named: "Relationship") {
      context.diagnose(.relationshipUnsupported, at: variable)
      return nil
    }

    if variable.hasAttribute(named: "Attribute") {
      context.diagnose(.attributeUnsupported, at: variable)
      return nil
    }

    if variable.hasAttribute(named: "Transient") {
      context.diagnose(.transientUnsupported, at: variable)
      return nil
    }

    let isQuery = variable.hasAttribute(named: "Query")
    let isBindable = variable.hasAttribute(named: "Bindable")

    if isQuery && isBindable {
      context.diagnose(.bindableQueryUnsupported, at: variable)
      return nil
    }

    guard variable.bindings.count == 1,
      let binding = variable.bindings.first,
      let identifier = binding.pattern.as(IdentifierPatternSyntax.self)
    else {
      context.diagnose(.queryBackedCollection, at: variable)
      return nil
    }

    guard let type = binding.typeAnnotation?.type else {
      context.diagnose(isQuery ? .explicitCollectionType : .explicitModelType, at: binding)
      return nil
    }

    if isBindable {
      guard let singleModelType = type.singleModelType,
        !singleModelType.isOptional
      else {
        context.diagnose(.bindableModelUnsupported, at: type)
        return nil
      }

      return WritableProperty(
        name: identifier.identifier.text,
        kind: .bindableModel,
        accessModifier: variable.projectedAccessModifier
      )
    }

    if isQuery {
      guard let elementType = type.queryElementType else {
        context.diagnose(.supportedCollectionType, at: type)
        return nil
      }

      return WritableProperty(
        name: identifier.identifier.text,
        kind: .queryCollection(elementType: elementType),
        accessModifier: variable.projectedAccessModifier
      )
    }

    if type.queryElementType != nil {
      context.diagnose(.queryBackedCollection, at: type)
      return nil
    }

    guard let singleModelType = type.singleModelType else {
      context.diagnose(.supportedModelType, at: type)
      return nil
    }

    return WritableProperty(
      name: identifier.identifier.text,
      kind: .singleModel(
        modelType: singleModelType.modelType,
        isOptional: singleModelType.isOptional
      ),
      accessModifier: variable.projectedAccessModifier
    )
  }
}

extension VariableDeclSyntax {
  fileprivate func hasAttribute(named expectedName: String) -> Bool {
    attributes.contains { attribute in
      guard case .attribute(let attributeSyntax) = attribute else {
        return false
      }

      let name = attributeSyntax.attributeName.trimmedDescription
      return name == expectedName || name.hasSuffix(".\(expectedName)")
    }
  }

  fileprivate var projectedAccessModifier: String {
    for modifier in modifiers {
      switch modifier.name.text {
      case "private", "fileprivate", "internal", "package":
        return modifier.name.text
      default:
        continue
      }
    }

    return ""
  }
}

private struct SingleModelType {
  let modelType: String
  let isOptional: Bool
}

extension TypeSyntax {
  fileprivate var queryElementType: String? {
    if let arrayType = self.as(ArrayTypeSyntax.self) {
      return arrayType.element.trimmedDescription
    }

    guard let identifierType = self.as(IdentifierTypeSyntax.self),
      identifierType.name.text == "Array",
      let arguments = identifierType.genericArgumentClause?.arguments,
      arguments.count == 1,
      let argument = arguments.first,
      case .type(let type) = argument.argument
    else {
      return nil
    }

    return type.trimmedDescription
  }

  fileprivate var singleModelType: SingleModelType? {
    if let modelType = bareSingleModelType {
      return SingleModelType(modelType: modelType, isOptional: false)
    }

    if let optionalType = self.as(OptionalTypeSyntax.self),
      let modelType = optionalType.wrappedType.bareSingleModelType {
      return SingleModelType(modelType: modelType, isOptional: true)
    }

    guard let identifierType = self.as(IdentifierTypeSyntax.self),
      identifierType.name.text == "Optional",
      let arguments = identifierType.genericArgumentClause?.arguments,
      arguments.count == 1,
      let argument = arguments.first,
      case .type(let type) = argument.argument,
      let modelType = type.bareSingleModelType
    else {
      return nil
    }

    return SingleModelType(modelType: modelType, isOptional: true)
  }

  private var bareSingleModelType: String? {
    if let identifierType = self.as(IdentifierTypeSyntax.self) {
      guard identifierType.genericArgumentClause == nil else {
        return nil
      }
      return trimmedDescription
    }

    if let memberType = self.as(MemberTypeSyntax.self) {
      guard memberType.genericArgumentClause == nil else {
        return nil
      }
      return trimmedDescription
    }

    return nil
  }
}
