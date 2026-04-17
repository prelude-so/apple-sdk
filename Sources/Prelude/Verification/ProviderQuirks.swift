import Foundation

/// Provider-specific quirks that modify request behavior based on the URL domain.
///
/// Different carriers have different requirements for silent verification requests.
/// This struct encapsulates those provider-specific behaviors.
struct ProviderQuirks {
    /// Headers to include in the request.
    let headers: [String: String]

    /// Default quirks used when no provider-specific quirks are found.
    static let `default` = Self(
        headers: [:]
    )

    /// Returns the appropriate quirks for the given URL based on its domain.
    /// - Parameter url: The request URL to analyze.
    /// - Returns: Provider-specific quirks for the URL's domain.
    static func forURL(_ url: URL) -> Self {
        guard let host = url.host?.lowercased() else {
            return .default
        }

        // Match against known provider domains
        for (pattern, quirks) in providerQuirksMap {
            if host == pattern || host.hasSuffix("." + pattern) {
                return quirks
            }
        }

        return .default
    }
}

private let providerQuirksMap: [String: ProviderQuirks] = [
    // Bouygues Telecom (French carrier)
    "bouyguestelecom.fr": ProviderQuirks(
        headers: [
            "accept": "text/html;q=0.9,application/xhtml+xml,application/xml,application/json,*/*;q=0.8",
        ]
    ),
]
