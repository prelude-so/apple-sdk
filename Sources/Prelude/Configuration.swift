import Foundation

/// Configuration is the configuration for the Prelude SDK.
public struct Configuration {
    /// The endpoint address of the Prelude API.
    var endpoint: Endpoint

    /// The SDK key that identifies your app within the Prelude API.
    var sdkKey: String

    /// Initialize the configuration.
    /// - Parameters:
    ///   - sdkKey: the SDK key. (Note: you can get one from the Prelude Dashboard)
    ///   - endpoint: the endpoint address of the Prelude API.
    public init(sdkKey: String, endpoint: Endpoint = .default) {
        self.endpoint = endpoint
        self.sdkKey = sdkKey
    }
}

extension Configuration {
    /// The endpoint address of the Prelude API.
    var endpointAddress: String {
        switch endpoint {
        case .default:
            return defaultEndpoint()
        case let .custom(address):
            return address
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
