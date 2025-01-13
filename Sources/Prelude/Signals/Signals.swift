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

extension Prelude {
    /// Collect and dispatch signals to the Prelude API, relying on the default 2 seconds timeout.
    public func dispatchSignals() async throws -> String {
        try await dispatchSignals(timeout: 2.0)
    }

    /// Collect and dispatch signals to the Prelude API, relying on the default 2 seconds timeout. It then
    /// calls the completion handler with the result.
    /// - Parameter completion: the completion handler.
    public func dispatchSignals(completion: @escaping (Result<String, Error>) -> Void) throws {
        Task {
            do {
                try await completion(.success(dispatchSignals()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Collect and dispatch signals to the Prelude API.
    /// - Parameter timeout: timeout for the dispatch operation HTTP requests.
    @available(iOS 16, *)
    public func dispatchSignals(timeout: Duration) async throws -> String {
        try await dispatchSignals(timeout: timeout.timeInterval())
    }

    /// Collect and dispatch signals to the Prelude API. It then calls the completion handler with the result.
    /// - Parameter timeout: timeout for the dispatch operation HTTP requests.
    /// - Parameter completion: the completion handler.
    @available(iOS 16, *)
    public func dispatchSignals(
        timeout: Duration,
        completion: @escaping (Result<String, Error>) -> Void
    ) throws {
        Task {
            do {
                try await completion(.success(dispatchSignals(timeout: timeout.timeInterval())))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Collect and dispatch signals to the Prelude API.
    /// - Parameter timeout: timeout for the dispatch operation HTTP requests.
    public func dispatchSignals(timeout: TimeInterval) async throws -> String {
        guard let endpointURL = URL(string: configuration.endpointAddress) else {
            throw SDKError.configurationError("cannot parse dispatch URL")
        }

        let signals = Signals()
        let payload = generatePayload(signals: signals, secret: retrieveTeamId())
        let userAgent = "Prelude/\(Version.versionString) Core/\(coreVersion()) (\(System.userAgentString()))"
        let availableNetworks = await AvailableNetworks.read()

        try await withThrowingTaskGroup(of: Void.self) { group in
            switch availableNetworks {
            case .none:
                throw SDKError.requestError("there are no available network interfaces to report the signals.")
            case .lanAndCellular:
                addNetworkTask(
                    group: &group,
                    sdkKey: configuration.sdkKey,
                    endpointURL: endpointURL,
                    userAgent: userAgent,
                    dispatchId: signals.id,
                    timeout: timeout,
                    interfaceType: .cellular
                )
                addNetworkTask(
                    group: &group,
                    sdkKey: configuration.sdkKey,
                    endpointURL: endpointURL,
                    userAgent: userAgent,
                    dispatchId: signals.id,
                    timeout: timeout,
                    payload: payload
                )
            case .onlyLan, .onlyCellular:
                addNetworkTask(
                    group: &group,
                    sdkKey: configuration.sdkKey,
                    endpointURL: endpointURL,
                    userAgent: userAgent,
                    dispatchId: signals.id,
                    timeout: timeout,
                    payload: payload
                )
            }

            do {
                try await group.waitForAll()
            } catch {
                throw SDKError.requestError("one or more requests failed to execute: \(error)")
            }
        }

        return signals.id
    }

    private func addNetworkTask(
        group: inout ThrowingTaskGroup<Void, any Error>,
        sdkKey: String,
        endpointURL: URL,
        userAgent: String,
        dispatchId: String,
        timeout: TimeInterval,
        interfaceType: NWInterface.InterfaceType? = nil,
        payload: Data? = nil
    ) {
        group.addTask {
            var request = Request(
                endpointURL.appendingPathComponent("/v1/signals"),
                method: payload != nil ? "POST" : "OPTIONS"
            )
            request.header("Connection", "close")
            request.header("User-Agent", userAgent)
            request.header("X-SDK-DispatchID", dispatchId)
            request.header("X-SDK-Key", sdkKey)
            if let interfaceType {
                request.interfaceType(interfaceType)
            }
            if let payload {
                request.header("Content-Encoding", "deflate")
                request.header("Content-Type", "application/vnd.prelude.signals")
                request.body(payload)
            }
            request.timeout(timeout)

            _ = try await request.send()
        }
    }

    /// Collect and dispatch signals to the Prelude API. It then calls the completion handler with the result.
    /// - Parameter timeout: timeout for the dispatch operation HTTP requests.
    /// - Parameter completion: the completion handler.
    public func dispatchSignals(
        timeout: TimeInterval,
        completion: @escaping (Result<String, Error>) -> Void
    ) throws {
        Task {
            do {
                try await completion(.success(dispatchSignals(timeout: timeout)))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
