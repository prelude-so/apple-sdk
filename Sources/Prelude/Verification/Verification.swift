import Foundation

private let maxRedirects = 20

extension Prelude {
    /// Perform silent phone number verification towards the cellular carrier's network, relying on the
    /// default 20 seconds timeout.
    /// - Parameter url: the request URL received from the back-end server.
    /// - Returns: a string representing the check code to send back to the back-end server.
    public func verifySilent(
        url: URL
    ) async throws -> String {
        try await verifySilent(url: url, timeout: 20.0)
    }

    /// Perform silent phone number verification towards the cellular carrier's network.
    /// - Parameter url: the request URL received from the back-end server.
    /// - Parameter timeout: timeout for the dispatch operation HTTP requests.
    /// - Returns: a string representing the check code to send back to the back-end server.
    public func verifySilent(
        url: URL,
        timeout: TimeInterval
    ) async throws -> String {
        guard let host = url.host else {
            throw SDKError.requestError("Invalid verification URL: missing host")
        }

        let baseHeaders = buildHeadersWithLocalQuirks(for: url)
        let deadline = Date().addingTimeInterval(timeout)
        var serverQuirks = ServerQuirks()
        var targetURL = url
        var targetMethod = "GET"
        var remainingRedirects = maxRedirects

        // Extract server quirks from the first Prelude response (always a redirect).
        if isTrustedHost(host) {
            var firstRequest = Request(url, method: "GET")
            for (key, value) in baseHeaders {
                firstRequest.header(key, value)
            }
            firstRequest.followRedirects(false)
            firstRequest.interfaceType(.cellular)
            firstRequest.operationTimeout(deadline.timeIntervalSinceNow)
            firstRequest.maxRetries(configuration.maxRetries)
            firstRequest.allowInsecureTLS(configuration.allowInsecureTLS)

            let firstResponse = try await firstRequest.send()
            switch firstResponse {
            case let .redirect(method, nextURL, responseHeaders):
                serverQuirks = ServerQuirks.from(responseHeaders: responseHeaders)
                targetURL = nextURL
                targetMethod = method
                remainingRedirects -= 1
            default:
                throw SDKError.requestError("unexpected response from verification server")
            }
        }

        // Build the main request with quirks applied; Request handles remaining redirects.
        guard let targetHost = targetURL.host else {
            throw SDKError.requestError("Invalid redirect URL: missing host")
        }
        let quirkHeaders = serverQuirks.headersForHost(targetHost)
        let mergedHeaders = baseHeaders.merging(quirkHeaders) { _, server in server }

        var request = Request(targetURL, method: targetMethod)
        for (key, value) in mergedHeaders {
            request.header(key, value)
        }
        request.followRedirects(true)
        request.maxRedirects(remainingRedirects)
        request.interfaceType(.cellular)
        request.operationTimeout(deadline.timeIntervalSinceNow)
        request.maxRetries(configuration.maxRetries)
        request.allowInsecureTLS(configuration.allowInsecureTLS)
        if let tlsVersion = serverQuirks.maxTLSVersionForHost(targetHost) {
            request.maxTLSVersion(tlsVersion)
        }

        let response = try await request.send()
        switch response {
        case let .success(data):
            guard let data else {
                throw SDKError.requestError("failed to execute silent verification request")
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            guard let decoded = try? decoder.decode(SilentCompleteResponse.self, from: data) else {
                throw SDKError.requestError("failed to retrieve code from silent verification request")
            }

            return decoded.code

        case .redirect:
            throw SDKError.requestError("too many redirects")

        case let .error(message):
            throw SDKError.requestError(message)
        }
    }

    /// Perform silent phone number verification towards the cellular carrier's network.
    /// - Parameter url: the request URL received from the back-end server.
    /// - Parameter timeout: timeout for the dispatch operation HTTP requests.
    /// - Parameter completion: the completion handler.
    public func verifySilent(
        url: URL,
        timeout: TimeInterval = 20.0,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        Task {
            do {
                try await completion(.success(verifySilent(url: url, timeout: timeout)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Perform silent phone number verification towards the cellular carrier's network.
    /// - Parameter url: the request URL received from the back-end server.
    /// - Parameter timeout: timeout for the dispatch operation HTTP requests.
    /// - Returns: a string representing the check code to send back to the back-end server.
    @available(iOS 16, *)
    public func verifySilent(
        url: URL,
        timeout: Duration
    ) async throws -> String {
        try await verifySilent(url: url, timeout: timeout.timeInterval())
    }

    /// Perform silent phone number verification towards the cellular carrier's network.
    /// - Parameter url: the request URL received from the back-end server.
    /// - Parameter timeout: timeout for the dispatch operation HTTP requests.
    /// - Parameter completion: the completion handler.
    @available(iOS 16, *)
    public func verifySilent(
        url: URL,
        timeout: Duration = .seconds(20),
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        Task {
            do {
                try await completion(.success(verifySilent(url: url, timeout: timeout.timeInterval())))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func buildHeadersWithLocalQuirks(for url: URL) -> [String: String] {
        let localQuirks = ProviderQuirks.forURL(url)
        var headers = [
            "connection": "close",
            "user-agent": buildUserAgent(),
            "accept": "*/*",
        ]
        for (key, value) in localQuirks.headers {
            headers[key] = value
        }
        return headers
    }

    private func isTrustedHost(_ host: String) -> Bool {
        switch configuration.endpoint {
        case .custom:
            return true
        case .default:
            guard let defaultURL = URL(string: defaultEndpoint()),
                  let defaultHost = defaultURL.host else { return false }
            return shareSameTLD(host, defaultHost)
        }
    }

    private func shareSameTLD(_ host1: String, _ host2: String) -> Bool {
        let components1 = host1.lowercased().split(separator: ".")
        let components2 = host2.lowercased().split(separator: ".")
        guard components1.count >= 2, components2.count >= 2 else { return false }
        let tld1 = components1.suffix(2).joined(separator: ".")
        let tld2 = components2.suffix(2).joined(separator: ".")
        return tld1 == tld2
    }
}

struct SilentCompleteResponse: Decodable {
    var code: String
}
