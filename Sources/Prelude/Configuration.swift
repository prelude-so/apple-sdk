import Foundation

/// Configuration is the configuration for the Prelude SDK.
public struct Configuration {
    /// The SDK key that identifies your app within the Prelude API.
    var sdkKey: String

    /// The endpoint address of the Prelude API.
    var endpoint: Endpoint

    // The list of features to be advertised as supported by the local implementation of the Prelude SDK.
    var implementedFeatures: Features = []

    /// The request timeout in seconds
    var timeout: TimeInterval = 2.0

    /// The maximum number of network retries in case of server error or timeout
    var maxRetries: Int = 0

    /// Initialize the configuration.
    /// - Parameters:
    ///   - sdkKey: the SDK key. (Note: you can get one from the Prelude Dashboard)
    ///   - endpoint: the endpoint address of the Prelude API.
    ///   - timeout: the default timeout for network requests.
    ///   - maxRetries: the default maximum number of retries allowed per failing network request.
    public init(
        sdkKey: String,
        endpoint: Endpoint = .default,
        implementedFeatures: Features = [],
        timeout: TimeInterval = 2.0,
        maxRetries: Int = 0
    ) {
        self.sdkKey = sdkKey
        self.endpoint = endpoint
        self.implementedFeatures = implementedFeatures
        self.timeout = timeout
        self.maxRetries = maxRetries
    }
}

extension Configuration {
    /// The endpoint address of the Prelude API.
    var endpointAddress: String {
        switch endpoint {
        case .default:
            defaultEndpoint()
        case let .custom(address):
            address
        }
    }
}

/// Endpoint is the endpoint address of the Prelude API.
public enum Endpoint {
    /// The default endpoint address.
    case `default`

    /// Custom endpoint address.
    case custom(String)
}

/// Features is a list of Prelude SDK features.
public struct Features: OptionSet {
    public let rawValue: UInt64

    public static let silentVerification = Self(rawValue: 1 << 0)

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }
}
