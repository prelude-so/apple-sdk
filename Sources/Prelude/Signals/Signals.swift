import Foundation
import Network

protocol CollectableFamily: Hashable {
    static func collect() -> Self
}

extension Signals {
    init() {
        id = dispatchId()
        timestamp = Date()
        application = Application.collect()
        device = Device.collect()
        hardware = Hardware.collect()
        network = Network.collect()
    }
}

public enum SignalsScope {
    case full, silentVerification
}

extension Prelude {
    /// Collect and dispatch signals to the Prelude API, relying on the default 2 seconds timeout.
    /// - Parameter scope: the signals data gathering scope.
    public func dispatchSignals(
        scope: SignalsScope = .full
    ) async throws -> String {
        try await dispatchSignals(
            scope: scope,
            timeout: configuration.timeout,
            maxRetries: configuration.maxRetries
        )
    }

    /// Collect and dispatch signals to the Prelude API, relying on the default 2 seconds timeout. It then
    /// calls the completion handler with the result.
    /// - Parameter scope: the signals data gathering scope.
    /// - Parameter completion: the completion handler.
    public func dispatchSignals(
        scope: SignalsScope = .full,
        completion: @escaping (Result<String, Error>) -> Void
    ) throws {
        Task {
            do {
                try await completion(.success(dispatchSignals(scope: scope)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Collect and dispatch signals to the Prelude API.
    /// - Parameter scope: the signals data gathering scope.
    /// - Parameter timeout: the timeout for the network requests.
    @available(iOS 16, *)
    public func dispatchSignals(
        scope: SignalsScope = .full,
        timeout: Duration
    ) async throws -> String {
        try await dispatchSignals(
            scope: scope,
            timeout: timeout.timeInterval(),
            maxRetries: configuration.maxRetries
        )
    }

    /// Collect and dispatch signals to the Prelude API. It then calls the completion handler with the result.
    /// - Parameter scope: the signals data gathering scope.
    /// - Parameter timeout: the timeout for the network requests.
    /// - Parameter completion: the completion handler.
    @available(iOS 16, *)
    public func dispatchSignals(
        scope: SignalsScope = .full,
        timeout: Duration,
        completion: @escaping (Result<String, Error>) -> Void
    ) throws {
        Task {
            do {
                try await completion(.success(
                    dispatchSignals(
                        scope: scope,
                        timeout: timeout.timeInterval(),
                        maxRetries: self.configuration.maxRetries
                    )
                ))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Collect and dispatch signals to the Prelude API.
    /// - Parameter scope: the signals data gathering scope.
    /// - Parameter timeout: the timeout for the network requests.
    /// - Parameter maxRetries: maximum number of retries allowed per failing network request.
    public func dispatchSignals(
        scope: SignalsScope = .full,
        timeout: TimeInterval,
        maxRetries: Int
    ) async throws -> String {
        guard let endpointURL = URL(string: configuration.endpointAddress) else {
            throw SDKError.configurationError("cannot parse dispatch URL")
        }

        let signals = Signals()
        lazy var payload = generatePayload(signals: signals, secret: retrieveTeamIdentifier())
        let userAgent = buildUserAgent()
        let availableNetworks = await getAvailableNetworks(vpnEnabled: signals.network.vpnEnabled ?? false)
        try await withThrowingTaskGroup(of: (hasPayload: Bool, error: Error?).self) { group in
            switch availableNetworks {
            case .none:
                throw SDKError.requestError("no available network interfaces")
            case .lanAndCellular:
                addNetworkTask(
                    group: &group,
                    sdkKey: configuration.sdkKey,
                    endpointURL: endpointURL,
                    userAgent: userAgent,
                    dispatchId: signals.id,
                    timeout: timeout,
                    maxRetries: maxRetries,
                    interfaceType: .cellular,
                    payload: nil,
                    implementedFeatures: configuration.implementedFeatures
                )
                if scope == .full {
                    addNetworkTask(
                        group: &group,
                        sdkKey: configuration.sdkKey,
                        endpointURL: endpointURL,
                        userAgent: userAgent,
                        dispatchId: signals.id,
                        timeout: timeout,
                        maxRetries: maxRetries,
                        interfaceType: nil,
                        payload: payload,
                        implementedFeatures: configuration.implementedFeatures
                    )
                }
            case .lanOnly, .cellularOnly, .vpn:
                addNetworkTask(
                    group: &group,
                    sdkKey: configuration.sdkKey,
                    endpointURL: endpointURL,
                    userAgent: userAgent,
                    dispatchId: signals.id,
                    timeout: timeout,
                    maxRetries: maxRetries,
                    interfaceType: nil,
                    payload: scope == .full ? payload : nil,
                    implementedFeatures: configuration.implementedFeatures
                )
            }

            var hasAnyPayloadRequest = false
            var payloadRequestFailed = false
            var errors: [Error] = []

            for try await result in group {
                if result.hasPayload {
                    hasAnyPayloadRequest = true
                    if let error = result.error {
                        payloadRequestFailed = true
                        errors.append(error)
                    }
                } else if let error = result.error {
                    errors.append(error)
                }
            }

            if payloadRequestFailed || (!hasAnyPayloadRequest && !errors.isEmpty) {
                let errorMessages = errors.map(\.localizedDescription).joined(separator: "; ")
                let prefix = errors.count == 1 ? "" : "Multiple requests failed. "
                throw SDKError.requestError("\(prefix)\(errorMessages)")
            }
        }

        return signals.id
    }

    /// Collect and dispatch signals to the Prelude API. It then calls the completion handler with the result.
    /// - Parameter scope: the signals data gathering scope.
    /// - Parameter timeout: the timeout for the network requests.
    /// - Parameter completion: the completion handler.
    public func dispatchSignals(
        scope: SignalsScope = .full,
        timeout: TimeInterval,
        maxRetries: Int,
        completion: @escaping (Result<String, Error>) -> Void
    ) throws {
        Task {
            do {
                try await completion(.success(dispatchSignals(
                    scope: scope,
                    timeout: timeout,
                    maxRetries: maxRetries
                )))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func addNetworkTask(
        group: inout ThrowingTaskGroup<(hasPayload: Bool, error: Error?), any Error>,
        sdkKey: String,
        endpointURL: URL,
        userAgent: String,
        dispatchId: String,
        timeout: TimeInterval,
        maxRetries: Int,
        interfaceType: NWInterface.InterfaceType?,
        payload: Data?,
        implementedFeatures: Features
    ) {
        group.addTask {
            let hasPayload = payload != nil
            var request = Request(
                endpointURL.appendingPathComponent("/v1/signals"),
                method: hasPayload ? "POST" : "OPTIONS"
            )
            request.header("Connection", "close")
            request.header("User-Agent", userAgent)
            request.header("X-SDK-DispatchID", dispatchId)
            request.header("X-SDK-Key", sdkKey)
            request.header("X-SDK-Implemented-Features", "\(implementedFeatures.rawValue)")
            if let interfaceType {
                request.interfaceType(interfaceType)
            }
            if let payload {
                request.header("Content-Encoding", "deflate")
                request.header("Content-Type", "application/vnd.prelude.signals")
                request.body(payload)
            }
            request.timeout(timeout)
            request.maxRetries(maxRetries)

            do {
                _ = try await request.send()
                return (hasPayload: hasPayload, error: nil)
            } catch {
                return (hasPayload: hasPayload, error: error)
            }
        }
    }
}
