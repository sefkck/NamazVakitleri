import Foundation
import Combine
import CoreLocation

/// Kullanıcının konumunu takip eder, şehir adını ve saat dilimini
/// (timezone) reverse geocoding ile çözer. Konum belirgin şekilde
/// değişmediyse (< 500m) gereksiz yeniden hesaplama yapmaz.
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var coordinate: CLLocationCoordinate2D?
    /// Konum henüz çözülmediğinde gösterilen geçici metin.
    let waitingText = LocalizationManager.shared.t("loc_waiting", fallback: "Konum bekleniyor...")
    @Published var cityName: String = LocalizationManager.shared.t("loc_waiting", fallback: "Konum bekleniyor...")
    @Published var timeZone: TimeZone = .current
    @Published var errorMessage: String?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        // 500 m'den küçük hareketlerde sistem hiç bildirim göndermesin.
        manager.distanceFilter = 500
    }

    @Published var isTakingTooLong = false

    private var timeoutTimer: Timer?

    func requestPermission() {
        // Sadece izin iste ve delegate callback'inin gelmesini bekleme;
        // izin durumu zaten belliyse (ör. daha önce verilmiş veya
        // reddedilmiş) doğrudan ona göre davran. Bu, ilk kurulumda
        // otomatik konumun bazen hiç tetiklenmeden takılı kalması
        // sorununa karşı ek bir güvence.
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            requestLocation()
        case .denied, .restricted:
            errorMessage = LocalizationManager.shared.t("loc_denied_short", fallback: "Konum izni verilmedi. Ayarlar'dan izin vermen gerekiyor.")
        @unknown default:
            manager.requestWhenInUseAuthorization()
        }
        // "Çok uzun sürüyor" sayacı sadece konum gerçekten istendiğinde
        // (requestLocation) başlar; izin penceresi açıkken başlamaz.
    }

    func requestLocation() {
        manager.startUpdatingLocation()
        startTimeoutWatch()
    }

    private func startTimeoutWatch() {
        isTakingTooLong = false
        timeoutTimer?.invalidate()
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            guard let self, self.coordinate == nil else { return }
            self.isTakingTooLong = true
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            requestLocation()
        case .denied, .restricted:
            errorMessage = LocalizationManager.shared.t("loc_denied_short", fallback: "Konum izni verilmedi. Ayarlar'dan izin vermen gerekiyor.")
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        if let current = coordinate {
            let previous = CLLocation(latitude: current.latitude, longitude: current.longitude)
            if location.distance(from: previous) < 500 { return }
        }

        coordinate = location.coordinate
        isTakingTooLong = false
        errorMessage = nil
        timeoutTimer?.invalidate()

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self, let placemark = placemarks?.first else { return }
            DispatchQueue.main.async {
                // subAdministrativeArea gerçek ilçedir (subLocality mahalle
                // seviyesindedir, bu yüzden "hâlâ mahalle yazıyor" sorununa
                // sebep oluyordu).
                self.cityName = PlaceName.format(placemark) ?? LocalizationManager.shared.t("loc_unknown", fallback: "Bilinmeyen konum")
                self.timeZone = placemark.timeZone ?? .current
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let clError = error as? CLError else {
            errorMessage = LocalizationManager.shared.t("loc_failed_retry", fallback: "Konum alınamadı, kısa süre içinde tekrar denenecek.")
            return
        }

        switch clError.code {
        case .locationUnknown:
            // Geçici bir sinyal kaybı; sistem kendiliğinden tekrar dener,
            // kullanıcıya gösterecek kalıcı bir sorun değil.
            break
        case .denied:
            // ÖNEMLİ: CoreLocation, izin GERÇEKTEN verilmişken bile
            // (özellikle izin yeni verildiğinde) bazen geçici bir
            // "denied" hatası fırlatabiliyor - bilinen bir sistem
            // tuhaflığı. Gerçekten reddedilmiş mi diye authorizationStatus'a
            // bakarak doğruluyoruz; izin aslında varsa yanlış alarm
            // vermek yerine kısa bir bekleyişle otomatik tekrar deniyoruz.
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    self?.manager.startUpdatingLocation()
                }
            } else {
                errorMessage = LocalizationManager.shared.t("loc_denied_full", fallback: "Konum alınamadı. Telefonun Ayarlar > Gizlilik ve Güvenlik > Konum Servisleri bölümünden hem genel konum servislerinin hem de bu uygulama için konum izninin açık olduğundan emin ol.")
            }
        case .network:
            errorMessage = LocalizationManager.shared.t("loc_network", fallback: "Konum belirlenirken bir ağ sorunu oluştu. İnternet bağlantını kontrol edip tekrar dene.")
        default:
            errorMessage = LocalizationManager.shared.t("loc_unavailable_now", fallback: "Konum şu anda alınamadı, kısa süre içinde tekrar denenecek.")
        }
    }
}
