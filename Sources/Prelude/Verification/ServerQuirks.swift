import Foundation
import Network

/// Server-driven quirks parsed from `X-SDK-Quirk-*` response headers.
struct ServerQuirks {
    struct Rule {
        let hostPattern: String
        var headerOverrides: [String: String]
        var maxTLSVersion: tls_protocol_version_t?
    }

    private(set) var rules: [Rule] = []

    var isEmpty: Bool {
        rules.isEmpty
    }

    /// Parse `X-SDK-Quirk-*` headers from response headers.
    static func from(responseHeaders: [String: String]) -> Self {
        var rulesByHost: [String: Rule] = [:]

        for (key, value) in responseHeaders {
            let lowercasedKey = key.lowercased()

            // CFHTTPMessage coalesces duplicate headers with ", ".
            // Split into individual directives respecting quoted values.
            let directives = splitDirectives(value)

            if lowercasedKey.hasPrefix("x-sdk-quirk-header-") {
                let headerName = String(key.dropFirst("X-SDK-Quirk-Header-".count)).lowercased()
                guard !headerName.isEmpty else { continue }

                for directive in directives {
                    let parsed = parseDirective(directive)
                    guard let host = parsed["host"] else { continue }
                    guard let headerValue = parsed["value"] else { continue }

                    var rule = rulesByHost[host] ?? Rule(hostPattern: host, headerOverrides: [:], maxTLSVersion: nil)
                    rule.headerOverrides[headerName] = headerValue
                    rulesByHost[host] = rule
                }
            } else if lowercasedKey == "x-sdk-quirk-tls" {
                for directive in directives {
                    let parsed = parseDirective(directive)
                    guard let host = parsed["host"] else { continue }
                    guard let versionStr = parsed["version"] else { continue }
                    guard let version = parseTLSVersion(versionStr) else { continue }

                    var rule = rulesByHost[host] ?? Rule(hostPattern: host, headerOverrides: [:], maxTLSVersion: nil)
                    rule.maxTLSVersion = version
                    rulesByHost[host] = rule
                }
            }
        }

        var quirks = Self()
        quirks.rules = Array(rulesByHost.values).sorted { arga, argb in
            hostSpecificity(arga.hostPattern) < hostSpecificity(argb.hostPattern)
        }
        return quirks
    }

    /// Return merged header overrides for a given host.
    func headersForHost(_ host: String) -> [String: String] {
        var result: [String: String] = [:]
        for rule in rules where hostMatches(pattern: rule.hostPattern, host: host) {
            for (key, value) in rule.headerOverrides {
                result[key] = value
            }
        }
        return result
    }

    /// Return TLS version override for a given host (nil = use default).
    func maxTLSVersionForHost(_ host: String) -> tls_protocol_version_t? {
        var result: tls_protocol_version_t?
        for rule in rules {
            if hostMatches(pattern: rule.hostPattern, host: host),
               let version = rule.maxTLSVersion {
                result = version
            }
        }
        return result
    }

    /// Split a coalesced header value (CFHTTPMessage joins duplicate headers with ", ")
    /// into individual directives, respecting quoted strings.
    private static func splitDirectives(_ header: String) -> [String] {
        var directives: [String] = []
        var current = ""
        var inQuotes = false
        var idx = header.startIndex

        while idx < header.endIndex {
            let char = header[idx]
            if char == "\"" {
                inQuotes.toggle()
                current.append(char)
            } else if !inQuotes, char == "," {
                let next = header.index(after: idx)
                if next < header.endIndex, header[next] == " " {
                    directives.append(current)
                    current = ""
                    idx = header.index(after: next)
                    continue
                } else {
                    current.append(char)
                }
            } else {
                current.append(char)
            }
            idx = header.index(after: idx)
        }

        if !current.isEmpty {
            directives.append(current)
        }

        return directives
    }

    /// Parse a directive string like `host="*.example.com";value="text/html"` into key-value pairs.
    /// All values must be quoted: `key="value"`. Unquoted values are skipped.
    private static func parseDirective(_ directive: String) -> [String: String] {
        let scanner = Scanner(string: directive)
        scanner.charactersToBeSkipped = CharacterSet(charactersIn: " ;")
        var result: [String: String] = [:]

        while !scanner.isAtEnd {
            guard let key = scanner.scanUpToString("=") else { break }
            guard scanner.scanString("=") != nil else { break }
            guard scanner.scanString("\"") != nil else { break }
            let value = scanner.scanUpToString("\"") ?? ""
            _ = scanner.scanString("\"")
            result[key.trimmingCharacters(in: .whitespaces)] = value
        }

        return result
    }

    private static func parseTLSVersion(_ version: String) -> tls_protocol_version_t? {
        switch version {
        case "1.2":
            return .TLSv12
        case "1.3":
            return .TLSv13
        default:
            return nil
        }
    }
}

private enum HostSpecificity: Int, Comparable {
    case wildcard = 0 // *
    case wildcardSuffix = 1 // *.example.com
    case exact = 2 // api.example.com

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

private func hostSpecificity(_ pattern: String) -> HostSpecificity {
    let lowered = pattern.lowercased()
    if lowered == "*" {
        return .wildcard
    } else if lowered.hasPrefix("*.") {
        return .wildcardSuffix
    } else {
        return .exact
    }
}

/// Host matching: `*` matches all, exact match, or wildcard suffix (`*.example.com`).
private func hostMatches(pattern: String, host: String) -> Bool {
    let host = host.lowercased()
    switch hostSpecificity(pattern) {
    case .wildcard:
        return true
    case .wildcardSuffix:
        return host.hasSuffix(pattern.lowercased().dropFirst())
    case .exact:
        return pattern.lowercased() == host
    }
}
