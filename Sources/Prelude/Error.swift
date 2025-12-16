import Foundation

/// SDKError is the error type for the Prelude SDK.
public enum SDKError: Error {
    /// A configuration error.
    case configurationError(String)

    /// An internal error.
    case internalError(String)

    /// A request error.
    case requestError(String)

    /// A system error.
    case systemError(String)

    /// Returns the underlying error message without any prefix.
    var message: String {
        switch self {
        case let .configurationError(message),
             let .internalError(message),
             let .requestError(message),
             let .systemError(message):
            return message
        }
    }
}

extension SDKError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .configurationError(message):
            return "ConfigurationError: \(message)"
        case let .internalError(message):
            return "InternalError: \(message)"
        case let .requestError(message):
            return "RequestError: \(message)"
        case let .systemError(message):
            return "SystemError: \(message)"
        }
    }
}

extension SDKError: CustomStringConvertible {
    public var description: String {
        errorDescription ?? "Unknown error"
    }
}
