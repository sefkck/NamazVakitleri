import Foundation
import Network
import Combine

/// İnternet bağlantısı var mı? Bağlantı geri gelince (ör. uçak modundan çıkınca)
/// hata gösteren ekranlar kendiliğinden yeniden yükleme yapabilsin diye.
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    @Published private(set) var isOnline = true
    private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async { self?.isOnline = path.status == .satisfied }
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
    }
}
