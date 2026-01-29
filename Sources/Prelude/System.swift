import Foundation

#if os(iOS)
    import UIKit
#endif

/// System is a namespace for system-related information.
enum System {
    /// The platform name.
    static let platform = "Apple"

    #if os(iOS)
        /// The system name.
        static let name: String? = UIDevice.current.systemName
    #elseif os(macOS)
        /// The system name.
        static let name: String? = "macOS"
    #else
        /// The system name.
        static let name: String? = nil
    #endif

    #if os(iOS)
        /// The system version.
        static let version: String? = UIDevice.current.systemVersion
    #elseif os(macOS)
        /// The system version.
        static let version: String? = ProcessInfo.processInfo.operatingSystemVersionString
    #else
        /// The system version.
        static let version: String? = nil
    #endif

    /// The user agent string.
    static var userAgentString = {
        var string = platform

        if let name {
            string.append("; \(name)")
            if let version {
                string.append(" \(version)")
            }
        } else {
            string.append("Unknown")
        }

        return string
    }
}
