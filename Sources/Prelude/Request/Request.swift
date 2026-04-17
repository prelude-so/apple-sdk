import Foundation
import Network
import Security

/// Request is a network HTTP request.
struct Request {
    private static let perHopTimeout: TimeInterval = 5.0

    private var url: URL

    private var method: String

    private var headers: [String: String]

    private var body: Data?

    private var followRedirects: Bool = false

    private var maxRedirects: Int = 20

    private var interfaceType: NWInterface.InterfaceType = .other

    private var timeout: TimeInterval = 2.0

    private var maxRetries: Int = 0

    private var retryAttempt: Int = 0

    private var operationDeadline: Date?

    private var maxTLSVersion: tls_protocol_version_t?

    private var allowInsecureTLS: Bool = false

    /// Create a new network HTTP request.
    /// - Parameters:
    ///   - url: the request URL.
    ///   - method: the request method.
    init(_ url: URL, method: String = "GET") {
        self.url = url
        self.method = method
        headers = [:]
    }
}

/// The result of sending a single-hop HTTP request.
enum Response {
    case success(Data?)
    case redirect(method: String, url: URL, responseHeaders: [String: String])
    case error(String)
}

extension Request {
    /// Set the request body.
    /// - Parameter data: the body data.
    mutating func body(_ data: Data) {
        body = data
    }

    /// Set the follow redirects flag.
    /// - Parameter state: the state of the flag.
    mutating func followRedirects(_ state: Bool) {
        followRedirects = state
    }

    /// Set a header key and value pair.
    /// - Parameters:
    ///   - key: the header key.
    ///   - value: the header value.
    mutating func header(_ key: String, _ value: String) {
        headers[key] = value
    }

    /// Set the interface type for the request.
    /// - Parameter type: the interface type.
    mutating func interfaceType(_ type: NWInterface.InterfaceType) {
        interfaceType = type
    }

    /// Set the timeout for the request.
    /// - Parameter timeout: the time interval.
    mutating func timeout(_ timeout: TimeInterval) {
        self.timeout = timeout
    }

    /// Set the maximum number of automatic retries in case of a timeout or server error.
    /// - Parameter maxRetries: the maximum number of retries.
    mutating func maxRetries(_ maxRetries: Int) {
        self.maxRetries = maxRetries
    }

    /// Set the maximum number of redirects to follow before returning the last redirect response.
    /// - Parameter maxRedirects: the maximum number of redirects.
    mutating func maxRedirects(_ maxRedirects: Int) {
        self.maxRedirects = maxRedirects
    }

    /// Set the total operation timeout. The request (including all redirects and retries)
    /// must complete within this duration. Each individual hop uses a shorter per-hop timeout,
    /// capped at the remaining operation time.
    /// - Parameter timeout: the total operation timeout.
    mutating func operationTimeout(_ timeout: TimeInterval) {
        operationDeadline = Date().addingTimeInterval(timeout)
    }

    /// Set the maximum TLS protocol version for the connection.
    /// - Parameter version: the maximum TLS version to negotiate.
    mutating func maxTLSVersion(_ version: tls_protocol_version_t) {
        maxTLSVersion = version
    }

    /// Allow insecure TLS by skipping certificate validation.
    /// - Parameter state: set to true to disable TLS certificate validation.
    mutating func allowInsecureTLS(_ state: Bool) {
        allowInsecureTLS = state
    }

    private func clone(url: URL, maxRedirects: Int? = nil, retryAttempt: Int? = nil) -> Request {
        var request = Request(url, method: method)
        request.headers = headers
        request.followRedirects = followRedirects
        request.maxRedirects = maxRedirects ?? self.maxRedirects
        request.interfaceType = interfaceType
        request.timeout = timeout
        request.maxRetries = maxRetries
        request.retryAttempt = retryAttempt ?? self.retryAttempt
        request.body = body
        request.operationDeadline = operationDeadline
        request.maxTLSVersion = maxTLSVersion
        request.allowInsecureTLS = allowInsecureTLS
        return request
    }

    /// Send the HTTP request and return the response.
    func send() async throws -> Response {
        if hasTimedOut() {
            throw SDKError.requestError("Operation timed out.")
        }

        guard let host = url.host else {
            throw SDKError.internalError("missing URL host")
        }

        let tlsOptions = NWProtocolTLS.Options()
        if let maxVersion = maxTLSVersion {
            sec_protocol_options_set_max_tls_protocol_version(
                tlsOptions.securityProtocolOptions,
                maxVersion
            )
        }

        if allowInsecureTLS {
            sec_protocol_options_set_verify_block(
                tlsOptions.securityProtocolOptions,
                { _, _, complete in
                    complete(true)
                },
                .global()
            )
        }
        let parameters = NWParameters(tls: tlsOptions)
        parameters.preferNoProxies = true
        if interfaceType != .other {
            parameters.requiredInterfaceType = interfaceType
        }

        let request = CFHTTPMessageCreateRequest(
            nil,
            method as CFString,
            url as CFURL,
            kCFHTTPVersion1_1
        ).takeRetainedValue()

        CFHTTPMessageSetHeaderFieldValue(request,
                                         "host" as CFString,
                                         host as CFString)
        CFHTTPMessageSetHeaderFieldValue(request,
                                         "x-sdk-request-date" as CFString,
                                         Date().RFC3339Format() as CFString)
        for (key, value) in headers {
            CFHTTPMessageSetHeaderFieldValue(request, key as CFString, value as CFString)
        }

        CFHTTPMessageSetHeaderFieldValue(request,
                                         "x-sdk-retry-attempt" as CFString,
                                         String(retryAttempt) as CFString)

        if let body {
            CFHTTPMessageSetHeaderFieldValue(
                request,
                "content-length" as CFString,
                String(body.count) as CFString
            )

            CFHTTPMessageSetBody(request, body as CFData)
        }

        guard let message = CFHTTPMessageCopySerializedMessage(request)?.takeRetainedValue() else {
            throw SDKError.internalError("cannot copy HTTP message")
        }

        let connection = NWConnection(to: NWEndpoint.url(url), using: parameters)
        let timer = deadline(for: connection, timeout: effectiveHopTimeout())

        connection.stateUpdateHandler = { state in
            switch state {
            case .cancelled:
                timer.cancel()
            case .ready:
                connection.send(content: message as Data,
                                isComplete: true,
                                completion: .idempotent)
            default:
                break
            }
        }

        connection.start(queue: .connection)

        return try await withCheckedThrowingContinuation { continuation in
            connection.receiveMessage { content, _, isComplete, error in
                timer.cancel()

                if let error {
                    if isTimeoutError(error) {
                        self.handleRetry(continuation: continuation)
                    } else {
                        continuation.resume(throwing: SDKError.requestError(error.localizedDescription))
                    }
                    return
                }

                guard isComplete else {
                    continuation.resume(throwing: SDKError.requestError("Invalid HTTP response."))
                    return
                }

                if let content {
                    let response = CFHTTPMessageCreateEmpty(nil, false).takeRetainedValue()

                    _ = content.withUnsafeBytes { buf in
                        CFHTTPMessageAppendBytes(response,
                                                 buf.baseAddress!.assumingMemoryBound(to: UInt8.self),
                                                 buf.count)
                    }

                    switch parseHTTPMessage(response) {
                    case let .retryable(status):
                        self.handleRetry(continuation: continuation)

                    case let .failure(status):
                        continuation.resume(throwing: SDKError.requestError("HTTP server error: \(status)"))

                    case let .redirect(method, url, responseHeaders):
                        if !self.followRedirects || self.maxRedirects == 0 {
                            continuation.resume(returning: .redirect(
                                method: method, url: url, responseHeaders: responseHeaders
                            ))
                        } else if self.hasTimedOut() {
                            continuation.resume(throwing: SDKError.requestError("Operation timed out."))
                        } else {
                            Task {
                                let request = self.clone(
                                    url: url,
                                    maxRedirects: self.maxRedirects - 1, retryAttempt: 0
                                )
                                do {
                                    try await continuation.resume(returning: request.send())
                                } catch {
                                    continuation.resume(throwing: error)
                                }
                            }
                        }

                    case let .success(data):
                        continuation.resume(returning: .success(data))
                    }
                } else {
                    continuation.resume(returning: .success(nil))
                }
            }
        }
    }

    private func isTimeoutError(_ error: NWError) -> Bool {
        error.localizedDescription.contains("Operation canceled")
    }

    private func hasTimedOut() -> Bool {
        guard let deadline = operationDeadline else {
            return false
        }
        return deadline.timeIntervalSinceNow <= 0
    }

    private func effectiveHopTimeout() -> TimeInterval {
        guard let deadline = operationDeadline else {
            return timeout
        }
        let remaining = deadline.timeIntervalSinceNow
        guard remaining > 0 else {
            return 0
        }
        return min(Self.perHopTimeout, remaining)
    }

    private func handleRetry(continuation: CheckedContinuation<Response, Error>) {
        if hasTimedOut() {
            continuation.resume(throwing: SDKError.requestError("Operation timed out."))
        } else if maxRetries > 0, retryAttempt < maxRetries {
            Task {
                let requestDelay = pow(2.0, Double(self.retryAttempt)) * 0.25
                let totalDelay = min(requestDelay, 10.0) // Cap at 10 seconds

                do {
                    try await Task.sleep(nanoseconds: UInt64(totalDelay * 1_000_000_000))

                    let result = try await self.clone(url: self.url, retryAttempt: self.retryAttempt + 1).send()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        } else {
            continuation.resume(throwing: SDKError.requestError("Max retries reached"))
        }
    }

    private func deadline(for connection: NWConnection, timeout: TimeInterval) -> any DispatchSourceTimer {
        let timer = DispatchSource.makeTimerSource(queue: .deadline)
        timer.schedule(deadline: .now() + timeout)
        timer.setEventHandler { connection.cancel() }
        timer.resume()

        return timer
    }

    private enum ParseHTTPMessageResult {
        case failure(Int)
        case redirect(String, URL, [String: String])
        case retryable(Int)
        case success(Data?)
    }

    private func parseHTTPMessage(_ message: CFHTTPMessage) -> ParseHTTPMessageResult {
        let status = CFHTTPMessageGetResponseStatusCode(message)

        switch status {
        case 200 ..< 300:
            return .success(CFHTTPMessageCopyBody(message)?.takeRetainedValue() as? Data)

        case 300 ... 303, 307, 308:
            guard let location = CFHTTPMessageCopyHeaderFieldValue(message, "Location" as CFString)?
                .takeRetainedValue() as? String, let url = URL(string: location) else {
                return .failure(status)
            }
            let responseHeaders = CFHTTPMessageCopyAllHeaderFields(message)?
                .takeRetainedValue() as? [String: String] ?? [:]
            return .redirect((307 ... 308).contains(status) ? method : "GET", url, responseHeaders)

        case 500 ..< 600:
            return .retryable(status)

        default:
            return .failure(status)
        }
    }
}

extension DispatchQueue {
    static var connection = DispatchQueue(
        label: "so.prelude.connection.queue",
        qos: .default
    )

    static var deadline = DispatchQueue(
        label: "so.prelude.deadline.queue",
        qos: .background
    )
}
