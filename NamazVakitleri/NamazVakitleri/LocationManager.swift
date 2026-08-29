import Foundation
import CoreLocation
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
    @Published var cityName: String = "Konum bekleniyor..."
    @Published var timeZone: TimeZone = .current
    @Published var errorMessage: String?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        manager.startUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            requestLocation()
        case .denied, .restricted:
            errorMessage = "Konum izni verilmedi. Ayarlar'dan izin vermen gerekiyor."
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

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self, let placemark = placemarks?.first else { return }
            DispatchQueue.main.async {
                self.cityName = placemark.locality ?? placemark.administrativeArea ?? "Bilinmeyen konum"
                self.timeZone = placemark.timeZone ?? .current
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
    }
}
