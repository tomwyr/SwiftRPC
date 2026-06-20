import SwiftSyntax

struct RPCMacroConfig {
  static let absoluteVarargMaxArity = 32

  var inlineHandler = false
  var varargMaxArity = 10
  var varargOverflowBehavior = RPCVarargOverflowBehavior.reject
  var serviceErrorType: String?

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
      case "serviceError":
        guard let serviceErrorType = arg.expression.serviceErrorTypeReference else {
          try throwDiagnostics(node: arg.expression, message: .invalidServiceError)
        }
        self.serviceErrorType = serviceErrorType
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
  let serviceErrorType: String?
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
  let failureServiceErrorType: String?

  init(from fn: FunctionDeclSyntax) {
    name = fn.name.text

    params = fn.signature.parameterClause.parameters.map(RPCParameter.init)

    let returnClause = fn.signature.returnClause
    returnType = returnClause?.type.trimmedDescription ?? "Void"
    isVoidReturn = returnClause.isVoidLike()
    let throwsClause = fn.signature.effectSpecifiers?.throwsClause
    failureServiceErrorType = throwsClause?.type?.failureServiceErrorType
  }

  /// The internal input struct name, e.g. `GetUser`
  var inputTypeName: String {
    "\(name.prefix(1).uppercased())\(name.dropFirst())"
  }

  /// The internal output struct name for methods that return inout mutations.
  var outputTypeName: String {
    "\(inputTypeName)Output"
  }

  /// The internal mutation struct name for methods that return inout mutations.
  var mutationTypeName: String {
    "\(inputTypeName)Mutations"
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

  /// Parameters whose values can be mutated by the server.
  var inOutParams: [RPCParameter] {
    params.filter(\.isInOut)
  }

  /// Whether the generated response needs to carry mutated parameter values.
  var hasInOutParams: Bool {
    !inOutParams.isEmpty
  }

  /// The generated throws clause, preserving typed RPC failures.
  var throwsClause: String {
    if let failureServiceErrorType {
      "throws(RPCFailure<\(failureServiceErrorType)>)"
    } else {
      "throws"
    }
  }

  /// The generated handler closure throws clause.
  var closureThrowsClause: String {
    if let failureServiceErrorType {
      "throws(RPCFailure<\(failureServiceErrorType)>)"
    } else {
      "throws"
    }
  }

  /// The method-level service error type, if declared with typed RPC failures.
  func serviceErrorType(default defaultServiceErrorType: String?) -> String? {
    failureServiceErrorType ?? defaultServiceErrorType
  }
}

struct RPCParameter {
  let label: String
  let name: String
  let elementType: String
  let isVariadic: Bool
  let isInOut: Bool

  init(from param: FunctionParameterSyntax) {
    label = param.firstName.text
    name = param.secondName?.text ?? label
    isVariadic = param.ellipsis != nil
    isInOut = param.isInOut

    if isInOut, let attributed = param.type.as(AttributedTypeSyntax.self) {
      elementType = attributed.baseType.trimmedDescription
    } else {
      elementType = param.type.trimmedDescription
    }
  }

  /// The generated method parameter type, preserving variadic syntax.
  var methodType: String {
    if isInOut {
      "inout \(elementType)"
    } else if isVariadic {
      "\(elementType)..."
    } else {
      elementType
    }
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

extension TypeSyntax {
  var failureServiceErrorType: String? {
    guard let identifier = self.as(IdentifierTypeSyntax.self),
      identifier.name.text == "RPCFailure",
      let arguments = identifier.genericArgumentClause?.arguments,
      arguments.count == 1,
      case .type(let serviceErrorType) = arguments.first?.argument
    else {
      return nil
    }

    return serviceErrorType.trimmedDescription
  }
}
