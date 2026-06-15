import SwiftSyntax

struct RPCMacroConfig {
  static let absoluteVarargMaxArity = 32

  var inlineHandler = false
  var varargMaxArity = 10
  var varargOverflowBehavior = RPCVarargOverflowBehavior.reject

  init(from node: AttributeSyntax) throws {
    guard case .argumentList(let args) = node.arguments else {
      return
    }

    for arg in args {
      switch arg.label?.text {
      case "inlineHandler":
        let boolArg = arg.expression.as(BooleanLiteralExprSyntax.self)
        inlineHandler = boolArg?.literal.text == "true"
      case "varargMaxArity":
        guard
          let value = Int(arg.expression.trimmedDescription),
          1...Self.absoluteVarargMaxArity ~= value
        else {
          try throwDiagnostics(
            node: arg.expression,
            message: .invalidVarargMaxArity(max: Self.absoluteVarargMaxArity),
          )
          continue
        }
        varargMaxArity = value
      case "varargOverflowBehavior":
        switch arg.expression.trimmedDescription {
        case ".reject", "RPCVarargOverflowBehavior.reject":
          varargOverflowBehavior = .reject
        case ".truncate", "RPCVarargOverflowBehavior.truncate":
          varargOverflowBehavior = .truncate
        default:
          try throwDiagnostics(node: arg.expression, message: .invalidVarargOverflowBehavior)
          continue
        }
      default:
        continue
      }
    }
  }
}

enum RPCVarargOverflowBehavior {
  case reject
  case truncate
}

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
  let params: [RPCParameter]
  let returnType: String
  let isVoidReturn: Bool

  init(from fn: FunctionDeclSyntax) {
    name = fn.name.text

    params = fn.signature.parameterClause.parameters.map(RPCParameter.init)

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
    let types = params.map(\.methodType).joined(separator: ", ")
    return "(\(types))"
  }

  /// The first variadic parameter, if this method declares one.
  var variadicParam: RPCParameter? {
    params.first(where: \.isVariadic)
  }
}

struct RPCParameter {
  let label: String
  let name: String
  let elementType: String
  let isVariadic: Bool

  init(from param: FunctionParameterSyntax) {
    label = param.firstName.text
    name = param.secondName?.text ?? label
    elementType = param.type.trimmedDescription
    isVariadic = param.ellipsis != nil
  }

  /// The generated method parameter type, preserving variadic syntax.
  var methodType: String {
    isVariadic ? "\(elementType)..." : elementType
  }

  /// The input payload field type, e.g. `String...` becomes `[String]`.
  var payloadType: String {
    isVariadic ? "[\(elementType)]" : elementType
  }

  /// The generated method parameter declaration, preserving external and local labels.
  var signatureFragment: String {
    if label == "_" {
      "_ \(name): \(methodType)"
    } else if label != name {
      "\(label) \(name): \(methodType)"
    } else {
      "\(label): \(methodType)"
    }
  }

  /// A generated call argument using this parameter's external label.
  func callArgument(value: String) -> String {
    if label == "_" {
      value
    } else {
      "\(label): \(value)"
    }
  }

  /// Generated inline closure variadic arguments for a fixed arity.
  func closureVariadicArguments(arity: Int) -> [String] {
    (0..<arity).map { "\(name)[\($0)]" }
  }
}
