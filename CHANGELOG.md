# Changelog

## 0.7.0

- Added protocol-level service error transport with `@RPC(serviceError:)`.
- Added typed RPC failures with `async throws(RPCFailure<ServiceError>)`.
- Added direct typed service errors with `async throws(ServiceError)`.

## 0.6.0

- Added variadic parameters support.
- Added `inout` parameters support.
- Removed unchecked sendability from production code.

## 0.5.0

- Added `@RPC` macro for defining type-safe RPC services from Swift protocols.
- Added generated client and server entry points for annotated services.
- Added HTTP client support through generated client initializers.
- Added Hummingbird integration for registering RPC services on routers.
- Added in-memory transport for same-process calls, tests, and local composition.
- Added `RPCError` for reporting explicit RPC failures.
