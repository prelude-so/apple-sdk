import CoreTelephony
import Foundation

extension Network: CollectableFamily {
    static func collect() -> Network {
        let data = CTCellularData()
        let info = CTTelephonyNetworkInfo()

        var cellularData: Bool? { // swiftlint:disable:this discouraged_optional_boolean
            guard data.restrictedState != .restrictedStateUnknown else {
                return nil
            }

            return data.restrictedState == .notRestricted
        }

        var cellularTechnologies: [String]? { // swiftlint:disable:this discouraged_optional_collection
            guard let value = info.serviceCurrentRadioAccessTechnology else {
                return nil
            }

            return Array(value.values.map { $0.dropPrefix("CTRadioAccessTechnology") })
        }

        var vpnEnabled: Bool {
            guard let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? NSDictionary,
                  let scoped = settings["__SCOPED__"] as? NSDictionary,
                  let allKeys = scoped.allKeys as? [String] else {
                return false
            }
            let keywords = ["tap", "tun", "ppp", "ipsec", "utun"]
            return allKeys.contains { key in
                keywords.contains { key.contains($0) }
            }
        }

        return Network(
            cellularData: cellularData,
            cellularTechnologies: cellularTechnologies,
            vpnEnabled: vpnEnabled
        )
    }
}
