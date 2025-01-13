import Foundation
import Network

/// Request is a network HTTP request.
struct Request {
    private var url: URL

    private var method: String

    private var headers: [String: String]

    private var body: Data?

    private var interfaceType: NWInterface.InterfaceType = .other

    private var timeout: TimeInterval = 2.0

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

extension Request {
    /// Set the request body.
    /// - Parameter data: the body data.
    mutating func body(_ data: Data) {
        body = data
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

    /// Send the HTTP request.
    /// - Parameter completion: the send completion handler.
    func send() async throws -> Data? {
        guard let host = url.host else {
            throw SDKError.internalError("missing URL host")
        }

        let parameters = NWParameters(tls: .init())
        parameters.preferNoProxies = true
        parameters.requiredInterfaceType = interfaceType

        let request = CFHTTPMessageCreateRequest(
            nil,
            method as CFString,
            url as CFURL,
            kCFHTTPVersion1_1
        ).takeRetainedValue()

        CFHTTPMessageSetHeaderFieldValue(request,
                                         "Host" as CFString,
                                         host as CFString)
        CFHTTPMessageSetHeaderFieldValue(request,
                                         "X-SDK-Request-Date" as CFString,
                                         ISO8601DateFormatter().string(from: Date()) as CFString)
        for (key, value) in headers {
            CFHTTPMessageSetHeaderFieldValue(request, key as CFString, value as CFString)
        }

        if let body {
            CFHTTPMessageSetHeaderFieldValue(
                request,
                "Content-Length" as CFString,
                String(body.count) as CFString
            )

            CFHTTPMessageSetBody(request, body as CFData)
        }

        guard let message = CFHTTPMessageCopySerializedMessage(request)?.takeRetainedValue() else {
            throw SDKError.internalError("cannot copy HTTP message")
        }

        let connection = NWConnection(to: NWEndpoint.url(url), using: parameters)
        let timer = deadline(for: connection, timeout: timeout)

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

        return try await receiveConnectionMessage(connection: connection)
    }

    private func receiveConnectionMessage(connection: NWConnection) async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            connection.receiveMessage { content, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: SDKError.requestError(error.localizedDescription))
                    return
                }

                guard isComplete else {
                    return
                }

                if let content {
                    let response = CFHTTPMessageCreateEmpty(nil, false).takeRetainedValue()

                    _ = content.withUnsafeBytes { buf in
                        CFHTTPMessageAppendBytes(response,
                                                 buf.baseAddress!.assumingMemoryBound(to: UInt8.self),
                                                 buf.count)
                    }

                    switch parseHTTPResponse(response: response) {
                    case let .httpError(status):
                        continuation.resume(throwing: SDKError.requestError("HTTP server error: \(status)"))
                    case let .success(body):
                        continuation.resume(returning: body)
                    case .parseError:
                        continuation.resume(returning: nil)
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func parseHTTPResponse(response: CFHTTPMessage) -> ParseHttpResult {
        let status = CFHTTPMessageGetResponseStatusCode(response)

        if !(200 ... 299).contains(status) {
            return .httpError(status)
        }

        if let body = CFHTTPMessageCopyBody(response)?.takeRetainedValue() {
            return .success(body as Data)
        }

        return .parseError
    }

    private func deadline(for connection: NWConnection, timeout: TimeInterval) -> any DispatchSourceTimer {
        let timer = DispatchSource.makeTimerSource(queue: .deadline)
        timer.schedule(deadline: .now() + timeout)
        timer.setEventHandler { connection.cancel() }
        timer.resume()

        return timer
    }

    enum ParseHttpResult {
        case httpError(Int)
        case success(Data)
        case parseError
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
