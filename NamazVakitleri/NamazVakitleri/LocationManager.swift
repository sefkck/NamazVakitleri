import Foundation
import Combine
import CoreLocation
import MapKit

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

        // Şehir adı ve saat dilimi gelene kadar saat dilimini boylamdan tahmin et:
        // telefonun saat dilimi konumdan çok farklıysa (yolculuk, test) vakitler
        // saatlerce kaymasın (New York'ta İstanbul saatiyle 7 saat kayıyordu).
        timeZone = Self.estimatedTimeZone(longitude: location.coordinate.longitude)
        resolvePlace(location, attempt: 0)
    }

    /// Boylama göre tahmini saat dilimi. Telefonun saat dilimi en fazla 1,5 saat
    /// farklıysa onu kullanır (yaz saati doğru kalır); değilse sabit GMT farkı.
    static func estimatedTimeZone(longitude: Double, device: TimeZone = .current) -> TimeZone {
        let estimate = Int((longitude / 15).rounded()) * 3600
        let deviceOffset = device.secondsFromGMT()
        if abs(deviceOffset - estimate) <= 5400 { return device }
        return TimeZone(secondsFromGMT: estimate) ?? device
    }

    /// Şehir adı + gerçek saat dilimi: CLGeocoder 3 kez denenir (0, 5, 20 sn);
    /// olmazsa MapKit'in ters adres aramasına geçilir.
    private func resolvePlace(_ location: CLLocation, attempt: Int) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                // Bu arada konum değiştiyse eski cevabı kullanma.
                guard let c = self.coordinate,
                      CLLocation(latitude: c.latitude, longitude: c.longitude).distance(from: location) < 1000 else { return }
                if let placemark = placemarks?.first {
                    self.cityName = PlaceName.format(placemark) ?? LocalizationManager.shared.t("loc_unknown", fallback: "Bilinmeyen konum")
                    if let tz = placemark.timeZone { self.timeZone = tz }
                    return
                }
                if attempt < 2 {
                    let delay: TimeInterval = attempt == 0 ? 5 : 20
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { self.resolvePlace(location, attempt: attempt + 1) }
                } else {
                    self.resolveWithMapKit(location)
                }
            }
        }
    }

    private func resolveWithMapKit(_ location: CLLocation) {
        guard let request = MKReverseGeocodingRequest(location: location) else { return }
        request.getMapItems { [weak self] items, _ in
            guard let self, let item = items?.first else { return }
            if let tz = item.timeZone { self.timeZone = tz }
            let name = item.addressRepresentations?.cityWithContext ?? item.name
            if let name, !name.isEmpty { self.cityName = name }
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
