import SwiftSyntax

struct RPCProtocolInfo {
  let name: String
  let access: RPCAccessLevel
  let methods: [RPCMethod]
}

enum RPCAccessLevel: String {
  case `private`
  case `fileprivate`
  case `internal`
  case `package`
  case `public`

  init(from modifiers: DeclModifierListSyntax) {
    let access = modifiers.lazy.compactMap { modifier -> RPCAccessLevel? in
      switch modifier.name.text {
      case "private": .private
      case "fileprivate": .fileprivate
      case "package": .package
      case "public": .public
      case "internal": .internal
      default: nil
      }
    }.first

    self = access ?? .internal
  }

  /// The access modifier prefix for generated declarations, e.g. `public `
  var declarationPrefix: String {
    switch self {
    case .internal:
      ""
    case .private, .fileprivate, .package, .public:
      "\(rawValue) "
    }
  }
}

struct RPCMethod {
  let name: String
  let params: [(label: String, name: String, type: String)]
  let returnType: String
  let isVoidReturn: Bool

  init(from fn: FunctionDeclSyntax) {
    name = fn.name.text

    params = fn.signature.parameterClause.parameters.map { param in
      let label = param.firstName.text
      let name = param.secondName?.text ?? label
      let type = param.type.trimmedDescription
      return (label: label, name: name, type: type)
    }

    let returnClause = fn.signature.returnClause
    returnType = returnClause?.type.trimmedDescription ?? "Void"
    isVoidReturn = returnClause.isVoidLike()
  }

  /// The internal input struct name, e.g. `GetUser`
  var inputTypeName: String {
    "\(name.prefix(1).uppercased())\(name.dropFirst())"
  }

  /// The route path, e.g. `/getUser`
  var route: String { "/\(name)" }

  /// The inline handler closure property name, e.g. `getUserHandler`
  var handlerPropertyName: String {
    "\(name)Handler"
  }

  /// The inline handler closure parameter type list, e.g. `(String, Int)`
  var closureParameterTypes: String {
    let types = params.map(\.type).joined(separator: ", ")
    return "(\(types))"
  }
}
