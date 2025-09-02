import Foundation
import Network

enum AvailableNetworks {
    case cellularOnly, lanOnly, lanAndCellular, vpn
}

extension DispatchQueue {
    static var networkMonitor = DispatchQueue(
        label: "so.prelude.networkMonitor.queue",
        qos: .default
    )
}

func getAvailableNetworks(vpnEnabled: Bool) async -> AvailableNetworks? {
    await withCheckedContinuation { continuation in
        let networkMonitor = NWPathMonitor()
        networkMonitor.pathUpdateHandler = { path in
            let result: AvailableNetworks? =
                switch (
                    path.availableInterfaces.contains {
                        $0.type == .wifi || $0.type == .wiredEthernet
                    },
                    path.availableInterfaces.contains {
                        $0.type == .cellular
                    },
                    vpnEnabled
                ) {
                case (true, true, false):
                    .lanAndCellular
                case (true, false, false):
                    .lanOnly
                case (false, true, false):
                    .cellularOnly
                case (false, false, false):
                    .none
                case (_, _, true):
                    .vpn
                }

            networkMonitor.cancel()
            continuation.resume(returning: result)
        }

        networkMonitor.start(queue: .networkMonitor)
    }
}
