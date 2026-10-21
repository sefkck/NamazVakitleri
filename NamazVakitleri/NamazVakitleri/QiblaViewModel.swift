import Foundation
import CoreLocation
import Combine

final class QiblaViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var headingDegrees: Double = 0
    @Published var qiblaBearing: Double = 0
    /// Kıblenin hesaplandığı konum (kıble haritası için).
    @Published var userCoordinate: CLLocationCoordinate2D?
    /// Okun dönüş açısı. Kuzeyden geçerken 359° → 0° atlaması olmasın diye
    /// her seferinde en kısa yönde biriktirilir (ok tam tur atmaz).
    @Published var arrowAngle: Double = 0
    @Published var isReady = false
    /// Pusula gösterilemiyorsa (sensör yok, konum hiç yok) gösterilen hata.
    @Published var errorMessage: String?
    /// Pusula gösterilirken altına yazılan bilgi notu (ör. son bilinen konum).
    @Published var infoMessage: String?
    /// Pusula verisi geçersiz; kullanıcı telefonu "8" çizerek kalibre etmeli.
    @Published var needsCalibration = false
    /// Cihazda pusula yok: ok dönmez, kıble açısı kuzeye göre gösterilir.
    @Published var compassUnavailable = false

    private let manager = CLLocationManager()
    static let kaabaLatitude = 21.4225
    static let kaabaLongitude = 39.8262
    private var fixedCoordinate: CLLocationCoordinate2D?

    override init() {
        super.init()
        manager.delegate = self
        manager.headingFilter = 1
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func start(fixedCoordinate: CLLocationCoordinate2D? = nil) {
        errorMessage = nil
        infoMessage = nil
        // Pusula yoksa bile kıble açısını (kuzeyden derece) göstermeye devam et.
        compassUnavailable = !CLLocationManager.headingAvailable()
        self.fixedCoordinate = fixedCoordinate
        manager.requestWhenInUseAuthorization()
        if !compassUnavailable {
            manager.startUpdatingHeading()
        }
        // Elle konumda da konum güncellemesi açık kalır: iOS "gerçek kuzey"
        // (trueHeading) değerini ancak konum açıkken verir. Kıble açısı
        // gerçek kuzeye göre olduğu için manyetik kuzeye düşmek Türkiye'de
        // 5-7° hata demek.
        manager.startUpdatingLocation()

        if let fixedCoordinate {
            setBearing(from: fixedCoordinate)
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    func setBearing(from coordinate: CLLocationCoordinate2D) {
        qiblaBearing = Self.calculateBearing(from: coordinate)
        userCoordinate = coordinate
        isReady = true
        updateArrow()
    }

    private func updateArrow() {
        let target = qiblaBearing - headingDegrees
        var delta = (target - arrowAngle).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        arrowAngle += delta
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        errorMessage = nil
        infoMessage = nil
        // Elle seçilen konumda kıble açısı o konuma göre kalır.
        guard fixedCoordinate == nil else { return }
        setBearing(from: location.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Negatif doğruluk = geçersiz pusula verisi; oku oynatma.
        guard newHeading.headingAccuracy >= 0 else {
            needsCalibration = true
            return
        }
        needsCalibration = newHeading.headingAccuracy > 25
        applyHeading(newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading)
    }

    func applyHeading(_ degrees: Double) {
        headingDegrees = degrees
        updateArrow()
    }

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        true
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Elle seçilen konum varsa açı zaten hesaplı; konum hatası önemsiz.
        if fixedCoordinate != nil { return }
        if let clError = error as? CLError, clError.code == .locationUnknown { return }

        // GPS şu anda konum veremiyorsa, daha önce Ana Sayfa'nın kaydettiği
        // son bilinen konuma geçici olarak düş - pusula yine görünür, altına
        // bilgi notu yazılır.
        let lat = UserDefaults.standard.double(forKey: "lastKnownLatitude")
        let lon = UserDefaults.standard.double(forKey: "lastKnownLongitude")
        if lat != 0 || lon != 0 {
            setBearing(from: CLLocationCoordinate2D(latitude: lat, longitude: lon))
            infoMessage = LocalizationManager.shared.t("home_cached_notice", fallback: "İnternet ve GPS sistemi açık olmadığı için geçici olarak son bilinen konum kullanılıyor.")
            return
        }

        // Daha önce bir konum geldiyse pusulayı gizleme.
        guard !isReady else { return }

        guard let clError = error as? CLError else {
            errorMessage = LocalizationManager.shared.t("qibla_no_location", fallback: "Konum alınamadığı için kıble yönü hesaplanamıyor. İnternet ve GPS bağlantını kontrol et.")
            return
        }
        switch clError.code {
        case .denied:
            errorMessage = LocalizationManager.shared.t("qibla_denied", fallback: "Kıble yönünü hesaplayabilmemiz için konum izni gerekiyor. Ayarlar > Gizlilik ve Güvenlik > Konum Servisleri'nden izin ver.")
        case .network:
            errorMessage = LocalizationManager.shared.t("loc_network", fallback: "Konum belirlenirken bir ağ sorunu oluştu. İnternet bağlantını kontrol edip tekrar dene.")
        default:
            errorMessage = LocalizationManager.shared.t("qibla_no_location", fallback: "Konum alınamadığı için kıble yönü hesaplanamıyor. İnternet ve GPS bağlantını kontrol et.")
        }
    }

    /// İki koordinat arasındaki büyük çember (great-circle) açısını hesaplar.
    static func calculateBearing(from coordinate: CLLocationCoordinate2D) -> Double {
        let lat1 = coordinate.latitude * .pi / 180
        let lon1 = coordinate.longitude * .pi / 180
        let lat2 = kaabaLatitude * .pi / 180
        let lon2 = kaabaLongitude * .pi / 180

        let deltaLon = lon2 - lon1
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        var bearing = atan2(y, x) * 180 / .pi
        bearing = (bearing + 360).truncatingRemainder(dividingBy: 360)
        return bearing
    }
}
