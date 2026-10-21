import Foundation
import CoreLocation
import SwiftUI
import Combine
import Adhan

/// İlk kurulum karşılama ekranındaki "Hadi Başlayalım" butonuna
/// basıldığında SADECE konum iznini isteyip, kullanıcı karar verene
/// kadar (izin verse de vermese de) bekleyen küçük bir yardımcı.
/// HomeView'ın kendi LocationManager'ından ayrı tutuyoruz çünkü bu
/// sadece "karar verildi mi?" sinyaline ihtiyaç duyuyor, sürekli konum
/// takibine değil.
final class OnboardingLocationRequester: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var onDecided: (() -> Void)?

    func request(onDecided: @escaping () -> Void) {
        self.onDecided = onDecided
        manager.delegate = self

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            // Zaten daha önce karar verilmiş (başka bir yoldan) - hemen devam et.
            finish()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager.authorizationStatus != .notDetermined else { return }
        finish()
    }

    private func finish() {
        let callback = onDecided
        onDecided = nil
        callback?()
    }
}
