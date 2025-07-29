import Foundation
import Network

enum AvailableNetworks {
    case cellularOnly, lanOnly, lanAndCellular
}

extension DispatchQueue {
    static var networkMonitor = DispatchQueue(
        label: "so.prelude.networkMonitor.queue",
        qos: .default
    )
}

func getAvailableNetworks() async -> AvailableNetworks? {
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
                    }
                ) {
                case (true, true):
                    .lanAndCellular
                case (true, false):
                    .lanOnly
                case (false, true):
                    .cellularOnly
                case (false, false):
                    .none
                }

            networkMonitor.cancel()
            continuation.resume(returning: result)
        }

        networkMonitor.start(queue: .networkMonitor)
    }
}
